const Group = require('../models/Group');
const User = require('../models/User');
const Expense = require('../models/Expense');
const GroupChat = require('../models/GroupChat');

// @desc    Create a new group
// @route   POST /api/groups
// @access  Private
exports.createGroup = async (req, res) => {
    try {
        console.log('[GroupController] Create request body:', req.body); // Debug log
        console.log('[GroupController] User:', req.user); // Debug log
        const { name, description } = req.body;
        const userId = req.user.id;

        const group = await Group.create({
            name,
            description: description || '',
            members: [{
                userId,
                name: req.user.name,
                email: req.user.email,
                upiId: req.user.upiId || '',
                amountOwed: 0,
                amountLent: 0
            }],
            createdBy: userId
        });

        res.status(201).json({
            success: true,
            data: { group }
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Get all groups for logged-in user
// @route   GET /api/groups
// @access  Private
exports.getGroups = async (req, res) => {
    try {
        const userId = req.user.id;
        console.log(`[GroupController] Fetching groups for user: ${userId} (${req.user.email})`); // Debug log
        const groups = await Group.findByMember(userId);
        console.log(`[GroupController] Found ${groups.length} groups for user`); // Debug log

        res.json({
            success: true,
            data: { groups },
            total: groups.length
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Get group by ID
// @route   GET /api/groups/:id
// @access  Private
exports.getGroupById = async (req, res) => {
    try {
        const group = await Group.findById(req.params.id);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Group not found'
            });
        }

        // Check if user is a member
        const isMember = group.members.some(m => m.userId === req.user.id);
        if (!isMember) {
            return res.status(403).json({
                success: false,
                message: 'You are not a member of this group'
            });
        }

        res.json({
            success: true,
            data: { group }
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Join group by invite code
// @route   POST /api/groups/join
// @access  Private
exports.joinGroup = async (req, res) => {
    try {
        const { inviteCode } = req.body;
        const userId = req.user.id;

        const group = await Group.findByInviteCode(inviteCode);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Invalid invite code'
            });
        }

        // Check if user is already a member
        const isMember = group.members.some(m => m.userId === userId);
        if (isMember) {
            return res.status(400).json({
                success: false,
                message: 'You are already a member of this group'
            });
        }

        // Add user to group
        const updatedGroup = await Group.addMember(group.id, {
            userId,
            name: req.user.name,
            email: req.user.email,
            upiId: req.user.upiId || ''
        });

        res.json({
            success: true,
            data: { group: updatedGroup },
            message: 'Joined group successfully'
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Add member to group
// @route   POST /api/groups/:id/members
// @access  Private
exports.addMember = async (req, res) => {
    try {
        const { memberEmail } = req.body;
        const group = await Group.findById(req.params.id);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Group not found'
            });
        }

        // Check if requester is a member
        const isMember = group.members.some(m => m.userId === req.user.id);
        if (!isMember) {
            return res.status(403).json({
                success: false,
                message: 'You are not a member of this group'
            });
        }

        // Find user by email
        const user = await User.findByEmail(memberEmail);

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found with this email'
            });
        }

        // Check if user is already a member
        const alreadyMember = group.members.some(m =>
            m.userId === user.id || m.email === memberEmail
        );
        if (alreadyMember) {
            return res.status(400).json({
                success: false,
                message: 'User is already a member'
            });
        }

        // Add member
        const updatedGroup = await Group.addMember(req.params.id, {
            userId: user.id,
            name: user.name,
            email: user.email,
            upiId: user.upiId || ''
        });

        res.json({
            success: true,
            data: { group: updatedGroup },
            message: 'Member added successfully'
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Delete group
// @route   DELETE /api/groups/:id
// @access  Private
exports.deleteGroup = async (req, res) => {
    try {
        const group = await Group.findById(req.params.id);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Group not found'
            });
        }

        // Only creator can delete
        if (group.createdBy !== req.user.id) {
            return res.status(403).json({
                success: false,
                message: 'Only the group creator can delete this group'
            });
        }

        await Group.deleteById(req.params.id);

        res.json({
            success: true,
            message: 'Group deleted successfully'
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Leave group
// @route   POST /api/groups/:id/leave
// @access  Private
exports.leaveGroup = async (req, res) => {
    try {
        const group = await Group.findById(req.params.id);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Group not found'
            });
        }

        // Check if user is a member
        const memberIndex = group.members.findIndex(m => m.userId === req.user.id);
        if (memberIndex === -1) {
            return res.status(400).json({
                success: false,
                message: 'You are not a member of this group'
            });
        }

        // Don't allow creator to leave if there are other members
        if (group.createdBy === req.user.id && group.members.length > 1) {
            return res.status(400).json({
                success: false,
                message: 'Group creator cannot leave. Delete the group or transfer ownership first.'
            });
        }

        // If last member leaving, delete the group
        if (group.members.length === 1) {
            await Group.deleteById(req.params.id);
            return res.json({
                success: true,
                message: 'You left the group. Group has been deleted as you were the last member.'
            });
        }

        // Remove member
        await Group.removeMember(req.params.id, req.user.id);

        res.json({
            success: true,
            message: 'You have left the group'
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Transfer group ownership
// @route   POST /api/groups/:id/transfer
// @access  Private
exports.transferOwnership = async (req, res) => {
    try {
        const { newOwnerId } = req.body;
        const group = await Group.findById(req.params.id);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Group not found'
            });
        }

        // Only current creator can transfer ownership
        if (group.createdBy !== req.user.id) {
            return res.status(403).json({
                success: false,
                message: 'Only the group creator can transfer ownership'
            });
        }

        // Check if new owner is a member
        const newOwner = group.members.find(m => m.userId === newOwnerId);
        if (!newOwner) {
            return res.status(400).json({
                success: false,
                message: 'New owner must be a member of the group'
            });
        }

        // Transfer ownership
        const updatedGroup = await Group.updateById(req.params.id, { createdBy: newOwnerId });

        res.json({
            success: true,
            data: { group: updatedGroup },
            message: 'Ownership transferred successfully'
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Settle up payment between members
// @route   POST /api/groups/:id/settle
// @access  Private
exports.settleUp = async (req, res) => {
    try {
        const { fromUserId, toUserId, amount } = req.body;
        const group = await Group.findById(req.params.id);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Group not found'
            });
        }

        // Verify requester is a member
        const isMember = group.members.some(m => m.userId === req.user.id);
        if (!isMember) {
            return res.status(403).json({
                success: false,
                message: 'You are not a member of this group'
            });
        }

        // Find the members involved
        const fromIndex = group.members.findIndex(m => m.userId === fromUserId);
        const toIndex = group.members.findIndex(m => m.userId === toUserId);

        if (fromIndex === -1 || toIndex === -1) {
            return res.status(400).json({
                success: false,
                message: 'Both members must be in the group'
            });
        }

        // Update balances.
        // A settlement is a cash transfer that reconciles who fronted money for shared
        // expenses. It is NOT new income/expense for either party (each member's fair
        // share was already recorded as a personal expense when the group expense was
        // added), so we only adjust the group balances here to avoid double counting.
        const settleAmount = Number(amount) || 0;
        group.members[fromIndex].amountOwed = Math.max(0, group.members[fromIndex].amountOwed - settleAmount);
        group.members[toIndex].amountLent = Math.max(0, group.members[toIndex].amountLent - settleAmount);

        const updatedGroup = await Group.updateById(req.params.id, { members: group.members });

        res.json({
            success: true,
            data: { group: updatedGroup },
            message: 'Payment settled successfully'
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Add expense to group
// @route   POST /api/groups/:id/expenses
// @access  Private
exports.addExpense = async (req, res) => {
    try {
        const { paidBy, paidByName, amount, description, splits, category, date } = req.body;
        const group = await Group.findById(req.params.id);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Group not found'
            });
        }

        // Check if user is a member
        const isMember = group.members.some(m => m.userId === req.user.id);
        if (!isMember) {
            return res.status(403).json({
                success: false,
                message: 'You are not a member of this group'
            });
        }

        const updatedGroup = await Group.addExpense(req.params.id, {
            paidBy,
            paidByName,
            amount,
            description,
            splits,
            category,
            date
        });

        // Link the group expense to each member's PERSONAL finance so that group
        // finance and personal finance stay connected. Every member's fair share is
        // recorded as a personal expense (tagged with the group + group-expense id so
        // it can be reversed on delete). This is the single source of truth for the
        // group -> personal linkage (the app no longer creates it client-side).
        const createdExpense = updatedGroup.expenses[updatedGroup.expenses.length - 1];
        const groupExpenseId = createdExpense ? createdExpense.id : null;

        if (groupExpenseId && Array.isArray(splits)) {
            const label = (description && description.trim().length > 0)
                ? `${description.trim()} (${updatedGroup.name})`
                : `Group expense - ${updatedGroup.name}`;

            await Promise.all(
                splits
                    .filter((s) => s && s.memberId && Number(s.amount) > 0)
                    .map((s) => Expense.create({
                        user: s.memberId,
                        amount: Number(s.amount),
                        category: category || 'others',
                        description: label,
                        date,
                        groupId: req.params.id,
                        groupExpenseId,
                        source: 'group'
                    }))
            );
        }

        res.json({
            success: true,
            data: { group: updatedGroup },
            message: 'Expense added successfully'
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Delete expense from group
// @route   DELETE /api/groups/:id/expenses/:expenseId
// @access  Private
exports.deleteGroupExpense = async (req, res) => {
    try {
        const { expenseId } = req.params;
        const group = await Group.findById(req.params.id);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Group not found'
            });
        }

        // Check if user is a member
        const isMember = group.members.some(m => m.userId === req.user.id);
        if (!isMember) {
            return res.status(403).json({
                success: false,
                message: 'You are not a member of this group'
            });
        }

        // Find the expense
        const expenseIndex = group.expenses.findIndex(e => e.id === expenseId);
        if (expenseIndex === -1) {
            return res.status(404).json({
                success: false,
                message: 'Expense not found'
            });
        }

        const expense = group.expenses[expenseIndex];

        // Reverse the balance changes
        for (const split of expense.splits) {
            const memberIndex = group.members.findIndex(m => m.userId === split.memberId);
            if (memberIndex !== -1) {
                group.members[memberIndex].amountOwed = Math.max(0, group.members[memberIndex].amountOwed - split.amount);
            }
        }

        // Reverse payer's balance
        const payerIndex = group.members.findIndex(m => m.userId === expense.paidBy);
        if (payerIndex !== -1) {
            group.members[payerIndex].amountLent = Math.max(0, group.members[payerIndex].amountLent - expense.amount);
        }

        // Remove expense
        group.expenses.splice(expenseIndex, 1);

        const updatedGroup = await Group.updateById(req.params.id, {
            expenses: group.expenses,
            members: group.members
        });

        // Remove the linked personal expenses that were created for each member's
        // share so personal finance stays in sync with the group.
        const memberIds = new Set([
            ...(expense.splits || []).map((s) => s.memberId),
            expense.paidBy
        ].filter(Boolean));

        await Promise.all(
            [...memberIds].map((memberId) =>
                Expense.deleteByGroupLink(memberId, req.params.id, expenseId).catch(() => 0)
            )
        );

        res.json({
            success: true,
            data: { group: updatedGroup },
            message: 'Expense deleted successfully'
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Send chat message to group
// @route   POST /api/groups/:id/chat
// @access  Private
exports.sendMessage = async (req, res) => {
    try {
        const { message } = req.body;
        const group = await Group.findById(req.params.id);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Group not found'
            });
        }

        // Verify user is a member
        const isMember = group.members.some(m => m.userId === req.user.id);
        if (!isMember) {
            return res.status(403).json({
                success: false,
                message: 'You are not a member of this group'
            });
        }

        const chatMessage = await GroupChat.create({
            groupId: req.params.id,
            userId: req.user.id,
            userName: req.user.name,
            message: message
        });

        res.status(201).json({
            success: true,
            data: { message: chatMessage }
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// @desc    Get chat messages for group
// @route   GET /api/groups/:id/chat
// @access  Private
exports.getMessages = async (req, res) => {
    try {
        const { after, limit } = req.query;
        const group = await Group.findById(req.params.id);

        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Group not found'
            });
        }

        // Verify user is a member
        const isMember = group.members.some(m => m.userId === req.user.id);
        if (!isMember) {
            return res.status(403).json({
                success: false,
                message: 'You are not a member of this group'
            });
        }

        let messages;
        if (after) {
            // Polling mode - get only new messages
            messages = await GroupChat.getNewMessages(req.params.id, after);
        } else {
            // Initial load - get recent messages
            messages = await GroupChat.getByGroupId(req.params.id, parseInt(limit) || 50);
        }

        res.json({
            success: true,
            data: { messages }
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
};
