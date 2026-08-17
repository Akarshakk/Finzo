const { getDb } = require('../config/firebase');
const { serializeDoc } = require('../utils/firestore');

const COLLECTION_NAME = 'groups';

// Generate invite code
const generateInviteCode = () => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
};

// Create group
const create = async (groupData) => {
    const db = getDb();

    // Validate members
    if (!groupData.members || !Array.isArray(groupData.members)) {
        throw new Error('Invalid members data');
    }

    const group = {
        name: groupData.name?.trim() || '',
        description: groupData.description?.trim() || '',
        members: groupData.members || [],
        expenses: [],
        createdBy: groupData.createdBy,
        inviteCode: generateInviteCode(),
        imageUrl: groupData.imageUrl || '',
        createdAt: new Date(),
        updatedAt: new Date()
    };

    const docRef = await db.collection(COLLECTION_NAME).add(group);
    return { id: docRef.id, ...group, createdAt: group.createdAt.toISOString(), updatedAt: group.updatedAt.toISOString() };
};

// Find groups by member userId
const findByMember = async (userId) => {
    const db = getDb();
    // Fetch all groups and filter (Firestore restriction workaround)
    const snapshot = await db.collection(COLLECTION_NAME).get();

    return snapshot.docs
        .map(doc => serializeDoc(doc))
        .filter(group => {
            if (!group || !Array.isArray(group.members)) return false;
            return group.members.some(member => member.userId === userId);
        });
};

// Find group by ID
const findById = async (id) => {
    const db = getDb();
    const doc = await db.collection(COLLECTION_NAME).doc(id).get();

    if (!doc.exists) return null;
    return serializeDoc(doc);
};

// Find group by invite code
const findByInviteCode = async (code) => {
    const db = getDb();
    const snapshot = await db.collection(COLLECTION_NAME)
        .where('inviteCode', '==', code.toUpperCase())
        .limit(1)
        .get();

    if (snapshot.empty) return null;
    return serializeDoc(snapshot.docs[0]);
};

// Update group
const updateById = async (id, updateData) => {
    const db = getDb();
    updateData.updatedAt = new Date();
    await db.collection(COLLECTION_NAME).doc(id).update(updateData);
    return await findById(id);
};

// Delete group
const deleteById = async (id) => {
    const db = getDb();
    await db.collection(COLLECTION_NAME).doc(id).delete();
    return true;
};

// Add member to group
const addMember = async (groupId, member) => {
    const group = await findById(groupId);
    if (!group) return null;

    // Check if already a member
    if (group.members.some(m => m.userId === member.userId)) {
        return group;
    }

    const newMember = {
        userId: member.userId,
        name: member.name,
        email: member.email,
        upiId: member.upiId || '',
        amountOwed: 0,
        amountLent: 0
    };

    group.members.push(newMember);
    return await updateById(groupId, { members: group.members });
};

// Remove member from group
const removeMember = async (groupId, userId) => {
    const group = await findById(groupId);
    if (!group) return null;

    group.members = group.members.filter(m => m.userId !== userId);
    return await updateById(groupId, { members: group.members });
};

// Add expense to group
const addExpense = async (groupId, expense) => {
    const group = await findById(groupId);
    if (!group) return null;

    const newExpense = {
        id: `exp_${Date.now()}`,
        paidBy: expense.paidBy,
        paidByName: expense.paidByName,
        amount: expense.amount,
        description: expense.description || 'Group Expense',
        splits: expense.splits || [],
        category: expense.category || 'other',
        date: expense.date ? new Date(expense.date) : new Date(),
        createdAt: new Date()
    };

    group.expenses.push(newExpense);

    // Update member balances logic 
    const payer = group.members.find(m => m.userId === expense.paidBy);
    if (payer) {
        let totalSplit = 0;
        expense.splits.forEach(split => {
            const member = group.members.find(m => m.userId === split.memberId);
            if (member && member.userId !== expense.paidBy) {
                member.amountOwed += split.amount;
                totalSplit += split.amount;
            }
        });
        payer.amountLent += totalSplit;
    }

    return await updateById(groupId, {
        expenses: group.expenses,
        members: group.members
    });
};

// Get total expenses for group
const getTotalExpenses = (group) => {
    return group.expenses.reduce((sum, expense) => sum + expense.amount, 0);
};

// Get member balance
const getMemberBalance = (group, userId) => {
    const member = group.members.find(m => m.userId === userId);
    if (!member) return 0;
    return member.amountLent - member.amountOwed;
};

module.exports = {
    COLLECTION_NAME,
    generateInviteCode,
    create,
    findByMember,
    findById,
    findByInviteCode,
    updateById,
    deleteById,
    addMember,
    removeMember,
    addExpense,
    getTotalExpenses,
    getMemberBalance
};
