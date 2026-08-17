/**
 * Smart Chatbot Controller
 * Uses Gemini for NLP understanding to handle both READ (queries) and WRITE (CRUD) operations
 * All operations are scoped to the logged-in user only
 */

const { GoogleGenerativeAI } = require('@google/generative-ai');
const Expense = require('../models/Expense');
const Income = require('../models/Income');
const Debt = require('../models/Debt');
const Group = require('../models/Group');
const PaperPortfolio = require('../models/PaperPortfolio');
const PaperTrade = require('../models/PaperTrade');
const Watchlist = require('../models/Watchlist');

// Initialize Gemini
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

// System prompt to enforce user-only operations
const SYSTEM_PROMPT = `You are Finzo, a helpful personal finance assistant. Today is ${new Date().toLocaleDateString('en-IN')}.

IMPORTANT RULES:
1. You can ONLY make changes to the logged-in user's account. 
2. If someone asks you to modify another person's account, data, or finances, politely explain: "I can only make changes to YOUR account. I cannot access or modify other users' data."
3. For any WRITE operation (add, update, delete), you MUST use the appropriate function call.
4. For questions about other people's finances (like "what is John's income?"), explain you can only access their own data.
5. Always confirm before making changes.

HANDLING MISSING INFORMATION:
- If user gives partial information (e.g., "add expense 500" without category), ask them for the missing required fields.
- For adding group members: If only name is given without email, ask: "What's [name]'s email address? I need it to send them an invitation."
- For expenses: If no category given, ask which category.
- For debts: If type (owe/owed) not clear, ask if they owe this person or if person owes them.
- Be conversational and helpful when asking for missing info.

SPECIAL ACTIONS:
- If user asks to "generate report" or "download portfolio report" or "create report", use the generatePortfolioReport function.
- For "add [person name] to [group]", ask for their email if not provided.

You do NOT have the user's financial data upfront.
You MUST use the provided tools to fetch data when the user asks.
- Use 'getIncome' for income queries
- Use 'getExpenses' for spending queries
- Use 'getBalance' for balance
- Use 'getPortfolio' for market data
- Use 'getDebts' for money owed`;

// Define all available functions the chatbot can use
const functionDeclarations = [
    // ============ READ Operations - Personal Finance ============
    {
        name: 'getIncome',
        description: 'Get user income for a specific month or current month',
        parameters: {
            type: 'object',
            properties: {
                month: { type: 'number', description: 'Month (1-12), defaults to current month' },
                year: { type: 'number', description: 'Year, defaults to current year' }
            }
        }
    },
    {
        name: 'getExpenses',
        description: 'Get user expenses, optionally filtered by category, date, or limit',
        parameters: {
            type: 'object',
            properties: {
                month: { type: 'number', description: 'Month (1-12)' },
                year: { type: 'number', description: 'Year' },
                category: { type: 'string', description: 'Category: clothes, drinks, education, food, fuel, fun, health, hotel, personal, pets, restaurants, tips, transport, others' },
                limit: { type: 'number', description: 'Number of recent expenses to get' }
            }
        }
    },
    {
        name: 'getBalance',
        description: 'Get current balance (income minus expenses) for this month',
        parameters: { type: 'object', properties: {} }
    },
    {
        name: 'getDebts',
        description: 'Get debts - money user owes to others or others owe to user',
        parameters: {
            type: 'object',
            properties: {
                type: { type: 'string', enum: ['owe', 'owed', 'all'], description: 'owe = I owe them, owed = they owe me, all = both' }
            }
        }
    },

    // ============ READ Operations - Groups ============
    {
        name: 'getGroups',
        description: 'Get all groups the user is a member of',
        parameters: { type: 'object', properties: {} }
    },
    {
        name: 'getGroupDetails',
        description: 'Get details of a specific group including expenses and balances',
        parameters: {
            type: 'object',
            properties: {
                groupName: { type: 'string', description: 'Name of the group to get details for' }
            },
            required: ['groupName']
        }
    },

    // ============ READ Operations - Markets ============
    {
        name: 'getPortfolio',
        description: 'Get user paper trading portfolio with holdings, share prices, current value, P&L (profit and loss), and market labs data. Use this for queries about: portfolio, holdings, shares, stocks owned, stock prices, P&L, profit, loss, market labs, investments',
        parameters: { type: 'object', properties: {} }
    },
    {
        name: 'getWatchlist',
        description: 'Get stocks in user watchlist',
        parameters: { type: 'object', properties: {} }
    },
    {
        name: 'getTradeHistory',
        description: 'Get user trade history - stocks bought or sold, recent transactions, trading activity. Use this for queries about: stocks bought today, stocks sold, trade history, recent trades, what did I buy, what did I sell',
        parameters: {
            type: 'object',
            properties: {
                limit: { type: 'number', description: 'Number of recent trades', default: 10 }
            }
        }
    },

    // ============ WRITE Operations - Expenses (CRUD) ============
    {
        name: 'addExpense',
        description: 'Add a new expense to user account',
        parameters: {
            type: 'object',
            properties: {
                amount: { type: 'number', description: 'Amount in rupees' },
                category: { type: 'string', description: 'Category: clothes, drinks, education, food, fuel, fun, health, hotel, personal, pets, restaurants, tips, transport, others' },
                description: { type: 'string', description: 'Description of expense' },
                date: { type: 'string', description: 'Date - can be "today", "yesterday", "last week", or YYYY-MM-DD format' }
            },
            required: ['amount', 'category']
        }
    },
    {
        name: 'updateExpense',
        description: 'Update an existing expense',
        parameters: {
            type: 'object',
            properties: {
                searchAmount: { type: 'number', description: 'Amount of expense to find' },
                searchCategory: { type: 'string', description: 'Category of expense to find' },
                newAmount: { type: 'number', description: 'New amount' },
                newCategory: { type: 'string', description: 'New category' },
                newDescription: { type: 'string', description: 'New description' }
            }
        }
    },
    {
        name: 'deleteExpense',
        description: 'Delete an expense',
        parameters: {
            type: 'object',
            properties: {
                amount: { type: 'number', description: 'Amount of expense to delete' },
                category: { type: 'string', description: 'Category of expense to delete' },
                description: { type: 'string', description: 'Description to match' }
            }
        }
    },

    // ============ WRITE Operations - Income (CRUD) ============
    {
        name: 'addIncome',
        description: 'Add income to user account',
        parameters: {
            type: 'object',
            properties: {
                amount: { type: 'number', description: 'Amount in rupees' },
                source: { type: 'string', description: 'Source: salary, freelance, pocket_money, investment, other' },
                description: { type: 'string', description: 'Description' }
            },
            required: ['amount']
        }
    },
    {
        name: 'updateIncome',
        description: 'Update existing income',
        parameters: {
            type: 'object',
            properties: {
                searchAmount: { type: 'number', description: 'Amount of income to find' },
                newAmount: { type: 'number', description: 'New amount' },
                newSource: { type: 'string', description: 'New source' },
                newDescription: { type: 'string', description: 'New description' }
            }
        }
    },
    {
        name: 'deleteIncome',
        description: 'Delete an income entry',
        parameters: {
            type: 'object',
            properties: {
                amount: { type: 'number', description: 'Amount of income to delete' },
                description: { type: 'string', description: 'Description to match' }
            }
        }
    },

    // ============ WRITE Operations - Debts (CRUD) ============
    {
        name: 'addDebt',
        description: 'Add a debt - money user owes someone or someone owes user',
        parameters: {
            type: 'object',
            properties: {
                amount: { type: 'number', description: 'Amount in rupees' },
                personName: { type: 'string', description: 'Name of the person' },
                type: { type: 'string', enum: ['owe', 'owed'], description: 'owe = I owe them, owed = they owe me' },
                description: { type: 'string', description: 'What the debt is for' },
                dueDate: { type: 'string', description: 'Due date in YYYY-MM-DD format' }
            },
            required: ['amount', 'personName', 'type']
        }
    },
    {
        name: 'settleDebt',
        description: 'Mark a debt as settled/paid',
        parameters: {
            type: 'object',
            properties: {
                personName: { type: 'string', description: 'Name of the person' },
                amount: { type: 'number', description: 'Amount to settle' }
            },
            required: ['personName']
        }
    },
    {
        name: 'deleteDebt',
        description: 'Delete a debt entry',
        parameters: {
            type: 'object',
            properties: {
                personName: { type: 'string', description: 'Name of the person' },
                amount: { type: 'number', description: 'Amount of debt' }
            },
            required: ['personName']
        }
    },

    // ============ WRITE Operations - Groups ============
    {
        name: 'createGroup',
        description: 'Create a new group for splitting expenses',
        parameters: {
            type: 'object',
            properties: {
                name: { type: 'string', description: 'Name of the group' },
                description: { type: 'string', description: 'Description of the group' }
            },
            required: ['name']
        }
    },
    {
        name: 'addGroupExpense',
        description: 'Add an expense to a group',
        parameters: {
            type: 'object',
            properties: {
                groupName: { type: 'string', description: 'Name of the group' },
                amount: { type: 'number', description: 'Total expense amount' },
                description: { type: 'string', description: 'What the expense is for' },
                splitType: { type: 'string', enum: ['equal', 'exact'], description: 'How to split - equal among all or exact amounts' }
            },
            required: ['groupName', 'amount', 'description']
        }
    },
    {
        name: 'leaveGroup',
        description: 'Leave a group',
        parameters: {
            type: 'object',
            properties: {
                groupName: { type: 'string', description: 'Name of the group to leave' }
            },
            required: ['groupName']
        }
    },
    {
        name: 'addMemberToGroup',
        description: 'Add a new member to an existing group. Requires member name and email address.',
        parameters: {
            type: 'object',
            properties: {
                groupName: { type: 'string', description: 'Name of the group to add member to' },
                memberName: { type: 'string', description: 'Name of the person to add' },
                memberEmail: { type: 'string', description: 'Email address of the person to invite' }
            },
            required: ['groupName', 'memberName', 'memberEmail']
        }
    },
    {
        name: 'askForMissingInfo',
        description: 'Use this when user provides incomplete info. Ask for the specific missing fields politely.',
        parameters: {
            type: 'object',
            properties: {
                missingFields: { type: 'string', description: 'What info is missing (e.g., "email address", "category", "amount")' },
                context: { type: 'string', description: 'What user was trying to do' },
                question: { type: 'string', description: 'The question to ask user for missing info' }
            },
            required: ['missingFields', 'question']
        }
    },

    // ============ Reports & Documents ============
    {
        name: 'generatePortfolioReport',
        description: 'Generate and download a PDF portfolio report with holdings, P&L, and charts',
        parameters: { type: 'object', properties: {} }
    },

    // ============ WRITE Operations - Markets ============
    {
        name: 'buyStock',
        description: 'Buy shares of a stock (paper trading)',
        parameters: {
            type: 'object',
            properties: {
                symbol: { type: 'string', description: 'Stock symbol like RELIANCE, TCS, INFY' },
                quantity: { type: 'number', description: 'Number of shares to buy' }
            },
            required: ['symbol', 'quantity']
        }
    },
    {
        name: 'sellStock',
        description: 'Sell shares of a stock (paper trading)',
        parameters: {
            type: 'object',
            properties: {
                symbol: { type: 'string', description: 'Stock symbol' },
                quantity: { type: 'number', description: 'Number of shares to sell, or "all" for all shares' }
            },
            required: ['symbol', 'quantity']
        }
    },
    {
        name: 'addToWatchlist',
        description: 'Add a stock to watchlist',
        parameters: {
            type: 'object',
            properties: {
                symbol: { type: 'string', description: 'Stock symbol to add' }
            },
            required: ['symbol']
        }
    },
    {
        name: 'removeFromWatchlist',
        description: 'Remove a stock from watchlist',
        parameters: {
            type: 'object',
            properties: {
                symbol: { type: 'string', description: 'Stock symbol to remove' }
            },
            required: ['symbol']
        }
    },

    // ============ User Settings & Goals ============
    {
        name: 'setSavingsTarget',
        description: 'Set monthly savings target percentage (how much of income to save)',
        parameters: {
            type: 'object',
            properties: {
                percentage: { type: 'number', description: 'Savings target as percentage of income (0-100)' }
            },
            required: ['percentage']
        }
    },
    {
        name: 'getSavingsTarget',
        description: 'Get current savings target and progress',
        parameters: { type: 'object', properties: {} }
    },
    {
        name: 'setMonthlyBudget',
        description: 'Set monthly spending budget limit',
        parameters: {
            type: 'object',
            properties: {
                amount: { type: 'number', description: 'Budget amount in rupees' }
            },
            required: ['amount']
        }
    },
    {
        name: 'getMonthlyBudget',
        description: 'Get current monthly budget and spending status',
        parameters: { type: 'object', properties: {} }
    },
    {
        name: 'getAnalytics',
        description: 'Get financial analytics - spending patterns, category breakdown, savings rate',
        parameters: {
            type: 'object',
            properties: {
                type: { type: 'string', enum: ['summary', 'categories', 'trends', 'comparison'], description: 'Type of analytics' }
            }
        }
    },
    {
        name: 'getFinancialTip',
        description: 'Get personalized financial advice based on user spending patterns',
        parameters: { type: 'object', properties: {} }
    },

    // ============ General Response ============
    {
        name: 'generalResponse',
        description: 'For ANY query that does not fit other functions: greetings, general questions, financial advice, explanations, clarifications, when user asks about other people accounts, or when the user asks something niche or unique. Use this to have a natural conversation.',
        parameters: {
            type: 'object',
            properties: {
                message: { type: 'string', description: 'Natural, helpful response to user. Be conversational and helpful.' }
            },
            required: ['message']
        }
    }
];

// Helper: Parse relative dates
function parseRelativeDate(dateStr) {
    const now = new Date();
    if (!dateStr) return now;

    const lower = dateStr.toLowerCase().trim();
    if (lower === 'today') return now;
    if (lower === 'yesterday') {
        const d = new Date(now);
        d.setDate(d.getDate() - 1);
        return d;
    }
    if (lower.includes('last week')) {
        const d = new Date(now);
        d.setDate(d.getDate() - 7);
        return d;
    }
    if (lower.includes('days ago')) {
        const match = lower.match(/(\d+)\s*days?\s*ago/);
        if (match) {
            const d = new Date(now);
            d.setDate(d.getDate() - parseInt(match[1]));
            return d;
        }
    }
    // Try parsing as date
    const parsed = new Date(dateStr);
    return isNaN(parsed.getTime()) ? now : parsed;
}

// Function implementations
const functionHandlers = {
    // ============ READ Handlers ============
    async getIncome(params, userId) {
        const now = new Date();
        const month = params.month || now.getMonth() + 1;
        const year = params.year || now.getFullYear();

        const incomes = await Income.findByUser(userId, { month, year });
        const total = incomes.reduce((sum, inc) => sum + inc.amount, 0);

        const incomeList = incomes.map(i => `• ₹${i.amount.toLocaleString('en-IN')} from ${i.source || 'income'}`).join('\n');

        return {
            type: 'data',
            data: { incomes, total, month, year },
            message: total > 0
                ? `Your income for ${month}/${year}:\n${incomeList}\n\nTotal: ₹${total.toLocaleString('en-IN')}`
                : `No income recorded for ${month}/${year}. Would you like to add some?`
        };
    },

    async getExpenses(params, userId) {
        const options = {};
        if (params.month && params.year) {
            const startDate = new Date(params.year, params.month - 1, 1);
            const endDate = new Date(params.year, params.month, 0, 23, 59, 59);
            options.startDate = startDate;
            options.endDate = endDate;
        }
        if (params.category) options.category = params.category;
        if (params.limit) options.limit = params.limit;

        const expenses = await Expense.findByUser(userId, options);
        const total = expenses.reduce((sum, exp) => sum + exp.amount, 0);

        const expenseList = expenses.slice(0, 5).map(e =>
            `• ₹${e.amount.toLocaleString('en-IN')} - ${e.category}${e.description ? ` (${e.description})` : ''}`
        ).join('\n');

        let message = `You have ${expenses.length} expenses totaling ₹${total.toLocaleString('en-IN')}`;
        if (params.category) message += ` in ${params.category}`;
        if (expenses.length > 0) message += `:\n\n${expenseList}`;
        if (expenses.length > 5) message += `\n...and ${expenses.length - 5} more`;

        return { type: 'data', data: { expenses, total }, message };
    },

    async getBalance(params, userId) {
        const now = new Date();
        const month = now.getMonth() + 1;
        const year = now.getFullYear();

        const incomes = await Income.findByUser(userId, { month, year });
        const expenses = await Expense.findByUser(userId, {
            startDate: new Date(year, month - 1, 1),
            endDate: new Date(year, month, 0, 23, 59, 59)
        });

        const totalIncome = incomes.reduce((sum, inc) => sum + inc.amount, 0);
        const totalExpense = expenses.reduce((sum, exp) => sum + exp.amount, 0);
        const balance = totalIncome - totalExpense;

        const balanceStatus = balance >= 0 ? '✅ Positive' : '⚠️ Negative';

        return {
            type: 'data',
            data: { totalIncome, totalExpense, balance },
            message: `📊 Your Balance This Month:\n\n💰 Income: ₹${totalIncome.toLocaleString('en-IN')}\n💸 Expenses: ₹${totalExpense.toLocaleString('en-IN')}\n━━━━━━━━━━━━━━━━\n${balanceStatus} Balance: ₹${Math.abs(balance).toLocaleString('en-IN')}`
        };
    },

    async getDebts(params, userId) {
        const debts = await Debt.findByUser(userId);
        let filtered = debts.filter(d => !d.settled);

        if (params.type === 'owe') {
            filtered = filtered.filter(d => d.type === 'owe');
        } else if (params.type === 'owed') {
            filtered = filtered.filter(d => d.type === 'owed');
        }

        const iOwe = filtered.filter(d => d.type === 'owe');
        const owedToMe = filtered.filter(d => d.type === 'owed');

        const iOweTotal = iOwe.reduce((sum, d) => sum + d.amount, 0);
        const owedToMeTotal = owedToMe.reduce((sum, d) => sum + d.amount, 0);

        let message = '💳 Your Debts:\n\n';
        if (iOwe.length > 0) {
            message += `📤 You owe (₹${iOweTotal.toLocaleString('en-IN')}):\n`;
            message += iOwe.map(d => `  • ₹${d.amount.toLocaleString('en-IN')} to ${d.personName}`).join('\n');
            message += '\n\n';
        }
        if (owedToMe.length > 0) {
            message += `📥 Owed to you (₹${owedToMeTotal.toLocaleString('en-IN')}):\n`;
            message += owedToMe.map(d => `  • ₹${d.amount.toLocaleString('en-IN')} from ${d.personName}`).join('\n');
        }
        if (filtered.length === 0) {
            message = '✨ You have no pending debts!';
        }

        return { type: 'data', data: { debts: filtered, iOweTotal, owedToMeTotal }, message };
    },

    async getGroups(params, userId) {
        const groups = await Group.findByMember(userId);

        if (groups.length === 0) {
            return { type: 'data', data: { groups: [] }, message: "You're not a member of any groups yet. Would you like to create one?" };
        }

        const groupList = groups.map(g => `• ${g.name} (${g.members?.length || 0} members)`).join('\n');

        return {
            type: 'data',
            data: { groups },
            message: `👥 Your Groups:\n\n${groupList}`
        };
    },

    async getGroupDetails(params, userId) {
        const groups = await Group.findByMember(userId);
        const group = groups.find(g => g.name.toLowerCase().includes(params.groupName.toLowerCase()));

        if (!group) {
            return { type: 'data', message: `Could not find a group named "${params.groupName}"` };
        }

        return {
            type: 'data',
            data: { group },
            message: `📋 ${group.name}:\n• Members: ${group.members?.length || 0}\n• Expenses: ${group.expenses?.length || 0}`
        };
    },

    async getPortfolio(params, userId) {
        const portfolio = await PaperPortfolio.findByUser(userId);

        if (!portfolio || !portfolio.holdings || portfolio.holdings.length === 0) {
            return {
                type: 'data',
                data: { portfolio: null },
                message: `📈 Your Portfolio:\n\n💵 Cash: ₹${(portfolio?.cash || 1000000).toLocaleString('en-IN')}\n📊 Holdings: None\n\nWould you like to buy some stocks?`
            };
        }

        const holdingsList = portfolio.holdings.slice(0, 5).map(h =>
            `• ${h.symbol}: ${h.quantity} shares @ ₹${h.averagePrice.toFixed(2)}`
        ).join('\n');

        return {
            type: 'data',
            data: { portfolio },
            message: `📈 Your Portfolio:\n\n💵 Cash: ₹${portfolio.cash.toLocaleString('en-IN')}\n\n📊 Holdings:\n${holdingsList}`
        };
    },

    async getWatchlist(params, userId) {
        const watchlist = await Watchlist.findByUser(userId);

        if (!watchlist || watchlist.length === 0) {
            return { type: 'data', data: { watchlist: [] }, message: '👀 Your watchlist is empty. Add some stocks to track!' };
        }

        const list = watchlist.map(w => `• ${w.symbol}`).join('\n');
        return { type: 'data', data: { watchlist }, message: `👀 Your Watchlist:\n\n${list}` };
    },

    async getTradeHistory(params, userId) {
        const limit = params.limit || 10;
        const trades = await PaperTrade.findByUser(userId, limit);

        if (!trades || trades.length === 0) {
            return { type: 'data', data: { trades: [] }, message: '📜 No trades yet. Start by buying some stocks!' };
        }

        const tradeList = trades.slice(0, 5).map(t =>
            `• ${t.type} ${t.quantity} ${t.symbol} @ ₹${t.price.toFixed(2)}`
        ).join('\n');

        return { type: 'data', data: { trades }, message: `📜 Recent Trades:\n\n${tradeList}` };
    },

    // ============ WRITE Handlers (Return Confirmation) ============
    async addExpense(params, userId) {
        const date = parseRelativeDate(params.date);

        return {
            type: 'confirmation',
            action: 'addExpense',
            params: {
                amount: params.amount,
                category: params.category,
                description: params.description || '',
                date: date.toISOString()
            },
            message: `Add expense of ₹${params.amount.toLocaleString('en-IN')} for ${params.category}${params.description ? ` (${params.description})` : ''}${params.date ? ` on ${date.toLocaleDateString('en-IN')}` : ''}?`
        };
    },

    async updateExpense(params, userId) {
        const expenses = await Expense.findByUser(userId, { limit: 20 });
        const match = expenses.find(e =>
            (params.searchAmount && e.amount === params.searchAmount) ||
            (params.searchCategory && e.category === params.searchCategory)
        );

        if (!match) {
            return { type: 'data', message: 'Could not find matching expense to update. Please be more specific.' };
        }

        return {
            type: 'confirmation',
            action: 'updateExpense',
            params: {
                id: match.id,
                amount: params.newAmount || match.amount,
                category: params.newCategory || match.category,
                description: params.newDescription || match.description
            },
            message: `Update expense from ₹${match.amount} (${match.category}) to ₹${params.newAmount || match.amount} (${params.newCategory || match.category})?`
        };
    },

    async deleteExpense(params, userId) {
        const expenses = await Expense.findByUser(userId, { limit: 20 });
        const match = expenses.find(e =>
            (params.amount && e.amount === params.amount) ||
            (params.category && e.category === params.category) ||
            (params.description && e.description?.includes(params.description))
        );

        if (!match) {
            return { type: 'data', message: 'Could not find matching expense to delete.' };
        }

        return {
            type: 'confirmation',
            action: 'deleteExpense',
            params: { id: match.id },
            message: `Delete expense of ₹${match.amount.toLocaleString('en-IN')} for ${match.category}?`
        };
    },

    async addIncome(params, userId) {
        return {
            type: 'confirmation',
            action: 'addIncome',
            params: {
                amount: params.amount,
                source: params.source || 'other',
                description: params.description || ''
            },
            message: `Add income of ₹${params.amount.toLocaleString('en-IN')}${params.source ? ` from ${params.source}` : ''}?`
        };
    },

    async updateIncome(params, userId) {
        const now = new Date();
        const incomes = await Income.findByUser(userId, { month: now.getMonth() + 1, year: now.getFullYear() });
        const match = incomes.find(i => params.searchAmount && i.amount === params.searchAmount);

        if (!match) {
            return { type: 'data', message: 'Could not find matching income to update.' };
        }

        return {
            type: 'confirmation',
            action: 'updateIncome',
            params: {
                id: match.id,
                amount: params.newAmount || match.amount,
                source: params.newSource || match.source,
                description: params.newDescription || match.description
            },
            message: `Update income from ₹${match.amount.toLocaleString('en-IN')} to ₹${(params.newAmount || match.amount).toLocaleString('en-IN')}?`
        };
    },

    async deleteIncome(params, userId) {
        const now = new Date();
        const incomes = await Income.findByUser(userId, { month: now.getMonth() + 1, year: now.getFullYear() });
        const match = incomes.find(i =>
            (params.amount && i.amount === params.amount) ||
            (params.description && i.description?.includes(params.description))
        );

        if (!match) {
            return { type: 'data', message: 'Could not find matching income to delete.' };
        }

        return {
            type: 'confirmation',
            action: 'deleteIncome',
            params: { id: match.id },
            message: `Delete income of ₹${match.amount.toLocaleString('en-IN')}?`
        };
    },

    async addDebt(params, userId) {
        const typeText = params.type === 'owe' ? `You owe ₹${params.amount.toLocaleString('en-IN')} to ${params.personName}` : `${params.personName} owes you ₹${params.amount.toLocaleString('en-IN')}`;

        return {
            type: 'confirmation',
            action: 'addDebt',
            params: {
                amount: params.amount,
                personName: params.personName,
                type: params.type,
                description: params.description || '',
                dueDate: params.dueDate
            },
            message: `Add debt: ${typeText}?`
        };
    },

    async settleDebt(params, userId) {
        const debts = await Debt.findByUser(userId);
        const match = debts.find(d =>
            !d.settled &&
            d.personName.toLowerCase().includes(params.personName.toLowerCase())
        );

        if (!match) {
            return { type: 'data', message: `Could not find an unsettled debt with ${params.personName}.` };
        }

        return {
            type: 'confirmation',
            action: 'settleDebt',
            params: { id: match.id },
            message: `Mark debt of ₹${match.amount.toLocaleString('en-IN')} with ${match.personName} as settled?`
        };
    },

    async deleteDebt(params, userId) {
        const debts = await Debt.findByUser(userId);
        const match = debts.find(d =>
            d.personName.toLowerCase().includes(params.personName.toLowerCase()) &&
            (!params.amount || d.amount === params.amount)
        );

        if (!match) {
            return { type: 'data', message: `Could not find debt with ${params.personName}.` };
        }

        return {
            type: 'confirmation',
            action: 'deleteDebt',
            params: { id: match.id },
            message: `Delete debt of ₹${match.amount.toLocaleString('en-IN')} with ${match.personName}?`
        };
    },

    async createGroup(params, userId) {
        return {
            type: 'confirmation',
            action: 'createGroup',
            params: {
                name: params.name,
                description: params.description || ''
            },
            message: `Create group "${params.name}"?`
        };
    },

    async addGroupExpense(params, userId) {
        const groups = await Group.findByMember(userId);
        const group = groups.find(g => g.name.toLowerCase().includes(params.groupName.toLowerCase()));

        if (!group) {
            return { type: 'data', message: `Could not find group "${params.groupName}".` };
        }

        return {
            type: 'confirmation',
            action: 'addGroupExpense',
            params: {
                groupId: group.id,
                amount: params.amount,
                description: params.description,
                splitType: params.splitType || 'equal'
            },
            message: `Add ₹${params.amount.toLocaleString('en-IN')} expense to "${group.name}" for ${params.description}?`
        };
    },

    async leaveGroup(params, userId) {
        const groups = await Group.findByMember(userId);
        const group = groups.find(g => g.name.toLowerCase().includes(params.groupName.toLowerCase()));

        if (!group) {
            return { type: 'data', message: `Could not find group "${params.groupName}".` };
        }

        return {
            type: 'confirmation',
            action: 'leaveGroup',
            params: { groupId: group.id },
            message: `Leave group "${group.name}"? This cannot be undone.`
        };
    },

    async addMemberToGroup(params, userId) {
        const groups = await Group.findByMember(userId);
        const group = groups.find(g => g.name.toLowerCase().includes(params.groupName.toLowerCase()));

        if (!group) {
            return { type: 'data', message: `Could not find group "${params.groupName}". Here are your groups: ${groups.map(g => g.name).join(', ')}` };
        }

        return {
            type: 'confirmation',
            action: 'addMemberToGroup',
            params: {
                groupId: group.id,
                memberName: params.memberName,
                memberEmail: params.memberEmail
            },
            message: `Add ${params.memberName} (${params.memberEmail}) to "${group.name}"?`
        };
    },

    async askForMissingInfo(params, userId) {
        // This just returns the question as a data response
        return {
            type: 'data',
            message: params.question
        };
    },

    async generatePortfolioReport(params, userId) {
        // Fetch portfolio data and return it with a flag for frontend to generate PDF
        const portfolio = await PaperPortfolio.getOrCreatePortfolio(userId);

        if (!portfolio || !portfolio.holdings || portfolio.holdings.length === 0) {
            return {
                type: 'data',
                message: "📊 You don't have any holdings in your portfolio yet. Start trading to build your portfolio!"
            };
        }

        // Return portfolio data with generateReport flag for frontend to handle
        return {
            type: 'action',
            action: 'generatePortfolioReport',
            data: { portfolio },
            message: '📄 Generating your portfolio report... The download dialog will appear shortly.'
        };
    },

    async buyStock(params, userId) {
        const symbol = params.symbol.toUpperCase().replace('.NS', '') + '.NS';
        return {
            type: 'confirmation',
            action: 'buyStock',
            params: {
                symbol: symbol,
                quantity: params.quantity
            },
            message: `Buy ${params.quantity} shares of ${params.symbol.toUpperCase()}?`
        };
    },

    async sellStock(params, userId) {
        const symbol = params.symbol.toUpperCase().replace('.NS', '') + '.NS';
        return {
            type: 'confirmation',
            action: 'sellStock',
            params: {
                symbol: symbol,
                quantity: params.quantity
            },
            message: `Sell ${params.quantity} shares of ${params.symbol.toUpperCase()}?`
        };
    },

    async addToWatchlist(params, userId) {
        const symbol = params.symbol.toUpperCase().replace('.NS', '') + '.NS';
        return {
            type: 'confirmation',
            action: 'addToWatchlist',
            params: { symbol },
            message: `Add ${params.symbol.toUpperCase()} to your watchlist?`
        };
    },

    async removeFromWatchlist(params, userId) {
        const symbol = params.symbol.toUpperCase().replace('.NS', '') + '.NS';
        return {
            type: 'confirmation',
            action: 'removeFromWatchlist',
            params: { symbol },
            message: `Remove ${params.symbol.toUpperCase()} from your watchlist?`
        };
    },

    // ============ Settings & Goals Handlers ============
    async setSavingsTarget(params, userId) {
        const pct = Math.max(0, Math.min(100, params.percentage));
        return {
            type: 'confirmation',
            action: 'setSavingsTarget',
            params: { percentage: pct },
            message: `Set your savings target to ${pct}% of your income?`
        };
    },

    async getSavingsTarget(params, userId) {
        const User = require('../models/User');
        const user = await User.findById(userId);
        const savingsTarget = user?.savingsTarget || 0;

        // Calculate actual savings this month
        const now = new Date();
        const month = now.getMonth() + 1;
        const year = now.getFullYear();

        const incomes = await Income.findByUser(userId, { month, year });
        const expenses = await Expense.findByUser(userId, {
            startDate: new Date(year, month - 1, 1),
            endDate: new Date(year, month, 0, 23, 59, 59)
        });

        const totalIncome = incomes.reduce((sum, i) => sum + i.amount, 0);
        const totalExpense = expenses.reduce((sum, e) => sum + e.amount, 0);
        const saved = totalIncome - totalExpense;
        const actualRate = totalIncome > 0 ? ((saved / totalIncome) * 100).toFixed(1) : 0;

        const status = actualRate >= savingsTarget ? '✅ On track!' : '⚠️ Below target';

        return {
            type: 'data',
            data: { savingsTarget, actualRate, saved, totalIncome },
            message: `🎯 Savings Target: ${savingsTarget}%\n📊 Actual Savings: ${actualRate}% (₹${saved.toLocaleString('en-IN')})\n${status}`
        };
    },

    async setMonthlyBudget(params, userId) {
        return {
            type: 'confirmation',
            action: 'setMonthlyBudget',
            params: { amount: params.amount },
            message: `Set your monthly budget to ₹${params.amount.toLocaleString('en-IN')}?`
        };
    },

    async getMonthlyBudget(params, userId) {
        const User = require('../models/User');
        const user = await User.findById(userId);
        const budget = user?.monthlyBudget || 0;

        // Calculate spending this month
        const now = new Date();
        const expenses = await Expense.findByUser(userId, {
            startDate: new Date(now.getFullYear(), now.getMonth(), 1),
            endDate: new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59)
        });

        const spent = expenses.reduce((sum, e) => sum + e.amount, 0);
        const remaining = budget - spent;
        const percentUsed = budget > 0 ? ((spent / budget) * 100).toFixed(0) : 0;

        let status = '✅ Under budget';
        if (percentUsed >= 100) status = '🚨 Over budget!';
        else if (percentUsed >= 80) status = '⚠️ Approaching limit';

        return {
            type: 'data',
            data: { budget, spent, remaining, percentUsed },
            message: budget > 0
                ? `💰 Monthly Budget: ₹${budget.toLocaleString('en-IN')}\n💸 Spent: ₹${spent.toLocaleString('en-IN')} (${percentUsed}%)\n💵 Remaining: ₹${remaining.toLocaleString('en-IN')}\n${status}`
                : 'No monthly budget set. Would you like to set one?'
        };
    },

    async getAnalytics(params, userId) {
        const now = new Date();
        const month = now.getMonth() + 1;
        const year = now.getFullYear();

        const expenses = await Expense.findByUser(userId, {
            startDate: new Date(year, month - 1, 1),
            endDate: new Date(year, month, 0, 23, 59, 59)
        });
        const incomes = await Income.findByUser(userId, { month, year });

        const totalExpense = expenses.reduce((sum, e) => sum + e.amount, 0);
        const totalIncome = incomes.reduce((sum, i) => sum + i.amount, 0);

        // Category breakdown
        const categories = {};
        expenses.forEach(e => {
            categories[e.category] = (categories[e.category] || 0) + e.amount;
        });

        const topCategories = Object.entries(categories)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5)
            .map(([cat, amt]) => `• ${cat}: ₹${amt.toLocaleString('en-IN')} (${((amt / totalExpense) * 100).toFixed(0)}%)`)
            .join('\n');

        const savingsRate = totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100).toFixed(1) : 0;

        return {
            type: 'data',
            data: { totalExpense, totalIncome, categories, savingsRate },
            message: `📊 Your Financial Analytics (${month}/${year}):\n\n💰 Income: ₹${totalIncome.toLocaleString('en-IN')}\n💸 Expenses: ₹${totalExpense.toLocaleString('en-IN')}\n💵 Savings Rate: ${savingsRate}%\n\n📈 Top Categories:\n${topCategories || 'No expenses yet'}`
        };
    },

    async getFinancialTip(params, userId) {
        const now = new Date();
        const expenses = await Expense.findByUser(userId, {
            startDate: new Date(now.getFullYear(), now.getMonth(), 1),
            endDate: now
        });

        const categories = {};
        expenses.forEach(e => {
            categories[e.category] = (categories[e.category] || 0) + e.amount;
        });

        const topCategory = Object.entries(categories).sort((a, b) => b[1] - a[1])[0];

        let tip = '💡 ';
        if (topCategory) {
            const [cat, amt] = topCategory;
            tip += `Your highest spending is on ${cat} (₹${amt.toLocaleString('en-IN')}). Consider setting a budget limit for this category to save more!`;
        } else {
            tip += 'Start tracking your expenses to get personalized savings tips!';
        }

        return { type: 'data', message: tip };
    },

    async generalResponse(params, userId) {
        return { type: 'data', message: params.message };
    }
};

// Execute confirmed action
const executeAction = async (action, params, userId) => {
    try {
        switch (action) {
            case 'addExpense':
                const expense = await Expense.create({
                    user: userId,
                    amount: params.amount,
                    category: params.category,
                    description: params.description,
                    date: new Date(params.date)
                });
                return { success: true, message: `✅ Expense of ₹${params.amount.toLocaleString('en-IN')} for ${params.category} added!` };

            case 'updateExpense':
                await Expense.updateById(params.id, {
                    amount: params.amount,
                    category: params.category,
                    description: params.description
                });
                return { success: true, message: '✅ Expense updated!' };

            case 'deleteExpense':
                await Expense.deleteById(params.id);
                return { success: true, message: '✅ Expense deleted!' };

            case 'addIncome':
                const now = new Date();
                await Income.create({
                    user: userId,
                    amount: params.amount,
                    source: params.source,
                    description: params.description,
                    month: now.getMonth() + 1,
                    year: now.getFullYear(),
                    date: now
                });
                return { success: true, message: `✅ Income of ₹${params.amount.toLocaleString('en-IN')} added!` };

            case 'updateIncome':
                await Income.updateById(params.id, {
                    amount: params.amount,
                    source: params.source,
                    description: params.description
                });
                return { success: true, message: '✅ Income updated!' };

            case 'deleteIncome':
                await Income.deleteById(params.id);
                return { success: true, message: '✅ Income deleted!' };

            case 'addDebt':
                await Debt.create({
                    user: userId,
                    amount: params.amount,
                    personName: params.personName,
                    type: params.type,
                    description: params.description,
                    dueDate: params.dueDate ? new Date(params.dueDate) : null
                });
                return { success: true, message: `✅ Debt with ${params.personName} added!` };

            case 'settleDebt':
                await Debt.updateById(params.id, { settled: true, settledAt: new Date() });
                return { success: true, message: '✅ Debt marked as settled!' };

            case 'deleteDebt':
                await Debt.deleteById(params.id);
                return { success: true, message: '✅ Debt deleted!' };

            case 'createGroup':
                await Group.create({
                    name: params.name,
                    description: params.description,
                    createdBy: userId,
                    members: [{ odid: userId, name: 'You', role: 'admin' }]
                });
                return { success: true, message: `✅ Group "${params.name}" created!` };

            case 'addGroupExpense':
                await Group.addExpense(params.groupId, {
                    amount: params.amount,
                    description: params.description,
                    paidBy: userId,
                    splitType: params.splitType
                });
                return { success: true, message: '✅ Group expense added!' };

            case 'leaveGroup':
                await Group.removeMember(params.groupId, userId);
                return { success: true, message: '✅ You have left the group.' };

            case 'addMemberToGroup':
                await Group.addMember(params.groupId, {
                    name: params.memberName,
                    email: params.memberEmail,
                    role: 'member'
                });
                return { success: true, message: `✅ ${params.memberName} has been invited to the group!` };

            case 'buyStock':
                // This would need market price - simplified
                return { success: true, message: `✅ Buy order for ${params.quantity} shares of ${params.symbol} placed!` };

            case 'sellStock':
                return { success: true, message: `✅ Sell order for ${params.quantity} shares of ${params.symbol} placed!` };

            case 'addToWatchlist':
                await Watchlist.add(userId, params.symbol);
                return { success: true, message: `✅ ${params.symbol.replace('.NS', '')} added to watchlist!` };

            case 'removeFromWatchlist':
                await Watchlist.remove(userId, params.symbol);
                return { success: true, message: `✅ ${params.symbol.replace('.NS', '')} removed from watchlist!` };

            case 'setSavingsTarget':
                const UserForSavings = require('../models/User');
                await UserForSavings.updateById(userId, { savingsTarget: params.percentage });
                return { success: true, message: `✅ Savings target set to ${params.percentage}%!` };

            case 'setMonthlyBudget':
                const UserForBudget = require('../models/User');
                await UserForBudget.updateById(userId, { monthlyBudget: params.amount });
                return { success: true, message: `✅ Monthly budget set to ₹${params.amount.toLocaleString('en-IN')}!` };

            default:
                return { success: false, message: 'Unknown action' };
        }
    } catch (error) {
        console.error('[Chat Execute] Error:', error);
        return { success: false, message: `Error: ${error.message}` };
    }
};

// Main chat endpoint
exports.chat = async (req, res) => {
    try {
        const { query, context, ragContext, conversationHistory } = req.body;

        if (!query) {
            return res.status(400).json({ success: false, message: 'Query is required' });
        }

        if (!process.env.GEMINI_API_KEY) {
            return res.status(500).json({ success: false, message: 'Gemini API key not configured. Please add GEMINI_API_KEY to .env file.' });
        }

        // Build context message with user's financial data
        let contextStr = SYSTEM_PROMPT;
        if (context) {
            contextStr += `\n\nUser's current financial snapshot: ${JSON.stringify(context)}`;
        }

        // Add RAG knowledge context if available (from PDF documents on port 5002)
        if (ragContext) {
            contextStr += `\n\nRelevant financial knowledge (from documents): ${ragContext}`;
        }

        // List of models to try in order of preference
        // Using models available in the Gemini API console
        const modelsToTry = [
            'gemini-3.0-flash',       // Requested by user
            'gemini-2.5-flash-lite',  // Requested by user
            'gemini-1.5-flash'        // Fallback
        ];
        let lastError = null;

        // Helper to sleep
        const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

        for (const modelName of modelsToTry) {
            let retryCount = 0;
            const maxRetries = 2; // Standard retry count

            while (retryCount <= maxRetries) {
                try {
                    const model = genAI.getGenerativeModel({
                        model: modelName,
                        tools: [{ functionDeclarations }]
                    });

                    // Build chat history - start with system context
                    const chatHistory = [
                        { role: 'user', parts: [{ text: contextStr }] },
                        { role: 'model', parts: [{ text: 'Understood! I am Finzo, your personal finance assistant. I can only make changes to YOUR account - I cannot access or modify other users data. How can I help you today?' }] }
                    ];

                    // Add conversation history from frontend if provided
                    if (conversationHistory && Array.isArray(conversationHistory)) {
                        for (const msg of conversationHistory) {
                            if (msg.role === 'user' && msg.content) {
                                chatHistory.push({ role: 'user', parts: [{ text: msg.content }] });
                            } else if (msg.role === 'assistant' && msg.content) {
                                chatHistory.push({ role: 'model', parts: [{ text: msg.content }] });
                            }
                        }
                    }

                    const chat = model.startChat({ history: chatHistory });

                    console.log(`[Chat] Attempting with model: ${modelName} (Attempt ${retryCount + 1})`);
                    const result = await chat.sendMessage(query);
                    console.log(`[Chat] Success with model: ${modelName}`);

                    const response = result.response;

                    // Check if Gemini wants to call a function
                    const functionCall = response.functionCalls()?.[0];

                    if (functionCall) {
                        const { name, args } = functionCall;
                        const handler = functionHandlers[name];

                        if (handler) {
                            const handlerResult = await handler(args || {}, req.user.id);
                            return res.json({ success: true, ...handlerResult });
                        }
                    }

                    // Fallback to text response
                    const textResponse = response.text();
                    return res.json({
                        success: true,
                        type: 'data',
                        message: textResponse || "I can only make changes to YOUR account. How can I help you with your personal finances?"
                    });

                } catch (error) {
                    lastError = error;

                    // If Rate Limited (429), retry with minimal delay
                    if (error.status === 429 || error.message?.includes('429') || error.message?.includes('quota')) {
                        console.warn(`[Chat] Rate limited on ${modelName}. Retrying quickly...`);

                        // Minimal wait time (1s) as requested to reduce buffer
                        let waitTime = 1000;

                        retryCount++;
                        if (retryCount <= maxRetries) {
                            await sleep(waitTime);
                            continue; // Retry same model
                        }
                    }

                    // If 404 (Not Found) or other error, break to try next model
                    console.error(`[Chat] Failed with ${modelName}:`, error.message);
                    break;
                }
            }
        }

        // If we get here, all models failed
        throw lastError;

    } catch (error) {
        console.error('[Chat] All models failed. Final Error:', error);

        // Handle rate limits and overloaded servers specifically
        if (error.status === 429 || error.message?.includes('429') || error.message?.includes('quota')) {
            return res.status(429).json({
                success: false,
                type: 'error',
                message: 'Brain overload! 🤯 I had too many requests. Please wait a moment and try again.',
                error: 'Rate limit exceeded'
            });
        }

        if (error.status === 503 || error.message?.includes('503')) {
            return res.status(503).json({
                success: false,
                type: 'error',
                message: 'My brain is temporarily overloaded. Please try again in a few seconds.',
                error: 'Service unavailable'
            });
        }

        return res.status(500).json({
            success: false,
            type: 'error',
            message: 'Error processing your request. Please try again.',
            error: error.message
        });
    }
};

// Execute confirmed action endpoint
exports.executeAction = async (req, res) => {
    try {
        const { action, params } = req.body;

        if (!action || !params) {
            return res.status(400).json({ success: false, message: 'Action and params required' });
        }

        const result = await executeAction(action, params, req.user.id);
        return res.json(result);

    } catch (error) {
        console.error('[Chat Execute] Error:', error);
        return res.status(500).json({
            success: false,
            message: 'Error executing action',
            error: error.message
        });
    }
};
