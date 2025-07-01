let gangs = {};
let logs = [];
let stashes = [];
let bossmenus = [];
let selectedGang = null;

let adminOrgChats = [];
let adminOrgGangs = {};

window.addEventListener('message', function(event) {
    if (event.data.action === 'show') {
        document.body.style.display = 'block';
    }
    if (event.data.action === 'updateData') {
        gangs = event.data.gangs || {};
        logs = event.data.logs || [];
        renderGangList();
        renderActivityFeed();
        renderLogs();
    }
    if (event.data.action === 'updateStashes') {
        stashes = event.data.stashes || [];
        renderStashTab();
    }
    if (event.data.action === 'updateBossMenus') {
        bossmenus = event.data.bossmenus || [];
        renderBossMenuTab();
    }
    if (event.data.action === 'showBossMenu') {
        showBossMenuModal(event.data.gang);
    }
    if (event.data.action === 'showInvite') {
        showInviteModal(event.data.gang, event.data.inviter);
    }
    if (event.data.action === 'inviteResult') {
        showInviteToast(event.data.gang, event.data.accepted);
    }
    if (event.data.action === 'showAdminOrg') {
        adminOrgGangs = event.data.gangs || {};
        showAdminOrgModal();
    }
    if (event.data.action === 'adminOrgChat') {
        adminOrgChats.push(event.data.data);
        updateAdminOrgChatLog();
    }
});

document.getElementById('home-btn').onclick = function() {
    setTab('home');
};
document.getElementById('logs-btn').onclick = function() {
    setTab('logs');
};
// Add Stash button
document.getElementById('stash-btn') && (document.getElementById('stash-btn').onclick = function() {
    setTab('stash');
});
// Add Boss Menu button
document.getElementById('bossmenu-btn') && (document.getElementById('bossmenu-btn').onclick = function() {
    setTab('bossmenu');
});

document.body.style.display = 'none'; // Hide UI by default

function setTab(tab) {
    document.querySelectorAll('.tab').forEach(function(el) {
        el.classList.remove('active');
    });
    document.getElementById(tab).classList.add('active');
    if(tab === 'stash') renderStashTab();
    if(tab === 'bossmenu') renderBossMenuTab();
}

function renderBossMenuTab() {
    let feed = document.getElementById('bossmenu-feed');
    if (!feed) return;
    feed.innerHTML = '';
    // Admin only: show create button
    const createBtn = document.createElement('button');
    createBtn.textContent = 'Place New Boss Menu';
    createBtn.onclick = function() {
        const gang = prompt('Gang Name:');
        if (gang) fetchNui('createBossMenu', { gang });
    };
    feed.appendChild(createBtn);
    // List boss menus
    if (bossmenus.length === 0) {
        feed.innerHTML += '<div>No boss menus placed yet.</div>';
        return;
    }
    bossmenus.forEach(bm => {
        const el = document.createElement('div');
        el.innerHTML = `<b>${bm.gang}</b>  ${bm.coords && bm.coords.x ? `(${bm.coords.x.toFixed(2)}, ${bm.coords.y.toFixed(2)}, ${bm.coords.z.toFixed(2)})` : ''}`;
        feed.appendChild(el);
    });
}

// --- Boss Menu Modal ---
function showBossMenuModal(gang) {
    let modal = document.getElementById('bossmenu-modal');
    if (!modal) {
        modal = document.createElement('div');
        modal.id = 'bossmenu-modal';
        modal.style.position = 'fixed';
        modal.style.top = '0';
        modal.style.left = '0';
        modal.style.width = '100vw';
        modal.style.height = '100vh';
        modal.style.background = 'rgba(0,0,0,0.9)';
        modal.style.color = '#fff';
        modal.style.zIndex = '9999';
        modal.style.display = 'flex';
        modal.style.flexDirection = 'column';
        modal.style.alignItems = 'center';
        modal.style.justifyContent = 'center';
        modal.innerHTML = `
            <div style="background:#222;padding:20px;border-radius:10px;max-width:900px;width:90vw;max-height:90vh;overflow:auto;">
                <h2>Boss Menu for ${gang}</h2>
                <button id="close-bossmenu">Close</button>
                <h3>Gang Management</h3>
                <div id="bossmenu-gangmanage"></div>
                <h3>Roles</h3>
                <div id="bossmenu-roles"></div>
                <h3>Invite Member</h3>
                <input id="bossmenu-govid" placeholder="Government ID" type="text" />
                <button id="bossmenu-invite">Invite</button>
            </div>
        `;
        document.body.appendChild(modal);
        document.getElementById('close-bossmenu').onclick = function() {
            modal.remove();
            fetchNui('closeBossMenu');
        };
        document.getElementById('bossmenu-invite').onclick = function() {
            const govId = document.getElementById('bossmenu-govid').value;
            if (govId) fetchNui('inviteMember', { gang, govId });
        };
    }
    // Render gang management
    renderBossMenuGangManage(gang);
    renderBossMenuRoles(gang);
}

function renderBossMenuGangManage(gang) {
    const div = document.getElementById('bossmenu-gangmanage');
    if (!div) return;
    const members = gangs[gang] && gangs[gang].members ? gangs[gang].members : {};
    div.innerHTML = '';
    // Announcement input
    if (myGang && (myRank === 'Leader' || myRank === 'Hierarchy')) {
        const ann = document.createElement('div');
        ann.style.marginBottom = '12px';
        ann.innerHTML = `<input id="bossmenu-announce" placeholder="Quick announcement..." type="text" style="width:220px;" /> <button id="bossmenu-announce-btn">Send</button>`;
        div.appendChild(ann);
        document.getElementById('bossmenu-announce-btn').onclick = function() {
            const msg = document.getElementById('bossmenu-announce').value;
            if (msg) fetchNui('bossAnnounce', { gang, message: msg });
            showBossMenuToast('Announcement sent!');
        };
    }
    Object.keys(members).forEach(identifier => {
        const m = members[identifier];
        const row = document.createElement('div');
        row.style.marginBottom = '6px';
        row.innerHTML = `<b>${m.name}</b> (<code>${identifier}</code>) <select>${ConfigRoles(gang).map(r => `<option${m.rank===r?' selected':''}>${r}</option>`).join('')}</select> <button>Remove</button>`;
        // Change role
        row.querySelector('select').onchange = function(e) {
            fetchNui('setMemberRole', { gang, identifier, role: e.target.value });
            showBossMenuToast(`Set ${m.name} to ${e.target.value}`);
        };
        // Remove member
        row.querySelector('button').onclick = function() {
            if (confirm('Remove '+m.name+'?')) {
                fetchNui('removeMemberBossMenu', { gang, identifier });
                showBossMenuToast(`Removed ${m.name}`);
            }
        };
        div.appendChild(row);
    });
}

// Listen for boss announcement
window.addEventListener('message', function(event) {
    if (event.data && event.data.action === 'showAnnouncement') {
        showAnnouncementModal(event.data.gang, event.data.message, event.data.sender);
    }
});

function showAnnouncementModal(gang, message, sender) {
    let modal = document.createElement('div');
    modal.style.position = 'fixed';
    modal.style.top = '30%';
    modal.style.left = '50%';
    modal.style.transform = 'translate(-50%, -50%)';
    modal.style.background = '#222';
    modal.style.color = '#fff';
    modal.style.padding = '30px 40px';
    modal.style.borderRadius = '16px';
    modal.style.boxShadow = '0 8px 32px #0008';
    modal.style.fontSize = '22px';
    modal.style.zIndex = '10010';
    modal.innerHTML = `<b>${gang} Announcement</b><br/><br/>${message}<br/><br/><span style='font-size:14px;'>From: ${sender}</span>`;
    document.body.appendChild(modal);
    setTimeout(() => modal.remove(), 6000);
}

function renderBossMenuRoles(gang) {
    const div = document.getElementById('bossmenu-roles');
    if (!div) return;
    let roles = ConfigRoles(gang);
    div.innerHTML = roles.map(r => `<span style="margin-right:8px;">${r} ${r!=='Leader'&&r!=='Hierarchy'?'<button data-role="'+r+'">Remove</button>':''}</span>`).join('');
    // Remove role
    div.querySelectorAll('button[data-role]').forEach(btn => {
        btn.onclick = function() {
            const role = btn.getAttribute('data-role');
            if (role) fetchNui('removeRole', { gang, role });
            showBossMenuToast(`Removed role ${role}`);
        };
    });
    // Add role
    const add = document.createElement('div');
    add.innerHTML = `<input id="bossmenu-newrole" placeholder="New Role" type="text" /> <button id="bossmenu-addrole">Add Role</button>`;
    div.appendChild(add);
    document.getElementById('bossmenu-addrole').onclick = function() {
        const role = document.getElementById('bossmenu-newrole').value;
        if (role) fetchNui('addRole', { gang, role });
        showBossMenuToast(`Added role ${role}`);
    };
}

function showBossMenuToast(msg) {
    let toast = document.createElement('div');
    toast.style.position = 'fixed';
    toast.style.bottom = '70px';
    toast.style.right = '30px';
    toast.style.background = '#007bff';
    toast.style.color = '#fff';
    toast.style.padding = '14px';
    toast.style.borderRadius = '8px';
    toast.style.fontSize = '16px';
    toast.style.zIndex = '10001';
    toast.textContent = msg;
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 4000);
}

function ConfigRoles(gang) {
    // Use server-synced roles if available, else default
    if (gangs[gang] && gangs[gang].roles) return gangs[gang].roles;
    return ['Leader','Hierarchy','PROBIE','TRIAL WHITELIST','WHITELISTED','CREW','ORG'];
}


// --- Invite Modal ---
function showInviteModal(gang, inviter) {
    let modal = document.getElementById('invite-modal');
    if (!modal) {
        modal = document.createElement('div');
        modal.id = 'invite-modal';
        modal.style.position = 'fixed';
        modal.style.top = '0';
        modal.style.left = '0';
        modal.style.width = '100vw';
        modal.style.height = '100vh';
        modal.style.background = 'rgba(0,0,0,0.8)';
        modal.style.color = '#fff';
        modal.style.zIndex = '10000';
        modal.style.display = 'flex';
        modal.style.flexDirection = 'column';
        modal.style.alignItems = 'center';
        modal.style.justifyContent = 'center';
        modal.innerHTML = `
            <div style="background:#222;padding:20px;border-radius:10px;max-width:400px;width:90vw;">
                <h2>Gang Invite</h2>
                <div>You have been invited to <b>${gang}</b> by <i>${inviter}</i>.</div>
                <button id="invite-accept">Join</button>
                <button id="invite-decline">Decline</button>
            </div>
        `;
        document.body.appendChild(modal);
        document.getElementById('invite-accept').onclick = function() {
            fetchNui('acceptInvite', { gang });
            modal.remove();
        };
        document.getElementById('invite-decline').onclick = function() {
            fetchNui('declineInvite', { gang });
            modal.remove();
        };
    }
}

// --- Toast for Invite Result ---
function showInviteToast(gang, accepted) {
    let toast = document.createElement('div');
    toast.style.position = 'fixed';
    toast.style.bottom = '30px';
    toast.style.right = '30px';
    toast.style.background = accepted ? '#28a745' : '#dc3545';
    toast.style.color = '#fff';
    toast.style.padding = '16px';
    toast.style.borderRadius = '8px';
    toast.style.fontSize = '18px';
    toast.style.zIndex = '10001';
    toast.textContent = accepted ? `Your client has accepted the invite to ${gang}!` : `Your client declined the invite to ${gang}.`;
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 5000);
}

function renderStashTab() {
    let feed = document.getElementById('stash-feed');
    if (!feed) return;
    feed.innerHTML = '';
    // Admin only: show create button
    const createBtn = document.createElement('button');
    createBtn.textContent = 'Open New Stash';
    createBtn.onclick = function() {
        const gang = prompt('Gang Name:');
        if (gang) fetchNui('createStash', { gang });
    };
    feed.appendChild(createBtn);
    // List stashes
    if (stashes.length === 0) {
        feed.innerHTML += '<div>No stashes created yet.</div>';
        return;
    }
    stashes.forEach(s => {
        const el = document.createElement('div');
        el.innerHTML = `<b>${s.gang}</b> — ${s.coords && s.coords.x ? `(${s.coords.x.toFixed(2)}, ${s.coords.y.toFixed(2)}, ${s.coords.z.toFixed(2)})` : ''} <button data-stash="${s.stashId}">Open</button>`;
        feed.appendChild(el);
        el.querySelector('button').onclick = function() {
            fetchNui('openStash', { stashId: s.stashId });
        };
    });
}

function renderGangList() {
    const list = document.getElementById('gang-list');
    list.innerHTML = '';
    const createBtn = document.createElement('button');
    createBtn.textContent = '+ Create Gang';
    createBtn.onclick = function() {
        const name = prompt('Enter new gang name:');
        if (name) fetchNui('createGang', { gangName: name });
    };
    list.appendChild(createBtn);
    Object.keys(gangs).forEach(gang => {
        const el = document.createElement('div');
        el.textContent = gang;
        el.className = (selectedGang === gang ? 'selected' : '');
        el.onclick = function() {
            selectedGang = gang;
            renderActivityFeed();
            renderGangList();
        };
        list.appendChild(el);
    });
    if (selectedGang) {
        const delBtn = document.createElement('button');
        delBtn.textContent = 'Delete Gang';
        delBtn.onclick = function() {
            if (confirm('Delete gang '+selectedGang+'?')) fetchNui('deleteGang', { gangName: selectedGang });
        };
        list.appendChild(delBtn);
    }
}

function renderActivityFeed() {
    const feed = document.getElementById('activity-feed');
    feed.innerHTML = '';
    if (!selectedGang || !gangs[selectedGang]) {
        feed.innerHTML = '<i>Select a gang to view members and activity.</i>';
        return;
    }
    // Members table
    const members = gangs[selectedGang].members || {};
    const table = document.createElement('table');
    const header = document.createElement('tr');
    header.innerHTML = '<th>Name</th><th>Rank</th><th>Action</th>';
    table.appendChild(header);
    Object.keys(members).forEach(identifier => {
        const m = members[identifier];
        const row = document.createElement('tr');
        row.innerHTML = `<td>${m.name}</td><td><select>${ConfigRanks().map(r => `<option${m.rank===r?' selected':''}>${r}</option>`).join('')}</select></td><td><button>Remove</button></td>`;
        // Change rank
        row.querySelector('select').onchange = function(e) {
            fetchNui('changeRank', { gangName: selectedGang, identifier, rank: e.target.value });
        };
        // Remove member
        row.querySelector('button').onclick = function() {
            if (confirm('Remove '+m.name+'?')) fetchNui('removeMember', { gangName: selectedGang, identifier });
        };
        table.appendChild(row);
    });
    feed.appendChild(table);
    // Add member
    const addBtn = document.createElement('button');
    addBtn.textContent = 'Add Member';
    addBtn.onclick = function() {
        const name = prompt('Player Name:');
        const identifier = prompt('Player Identifier:');
        if (name && identifier) {
            const rank = prompt('Rank ('+ConfigRanks().join(', ')+'):', ConfigRanks()[0]);
            if (rank) fetchNui('addMember', { gangName: selectedGang, identifier, name, rank });
        }
    };
    feed.appendChild(addBtn);
    // Activity log
    const act = document.createElement('div');
    act.innerHTML = '<h3>Gang Activity Log</h3>' + (gangs[selectedGang].logs||[]).slice(-10).reverse().map(l => `<div>${l}</div>`).join('');
    feed.appendChild(act);
}

function renderLogs() {
    const feed = document.getElementById('logs-feed');
    feed.innerHTML = logs.slice(-30).reverse().map(l => `<div>${l}</div>`).join('');
}

function fetchNui(event, data) {
    fetch(`https://${GetParentResourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    });
}

function ConfigRanks() {
    return ['PROBIE','TRIAL WHITELIST','WHITELISTED','CREW','ORG'];
}

// --- Admin Org Modal ---
function showAdminOrgModal() {
    let modal = document.getElementById('admin-org-modal');
    if (!modal) {
        modal = document.createElement('div');
        modal.id = 'admin-org-modal';
        modal.style.position = 'fixed';
        modal.style.top = '0';
        modal.style.left = '0';
        modal.style.width = '100vw';
        modal.style.height = '100vh';
        modal.style.background = 'rgba(0,0,0,0.9)';
        modal.style.color = '#fff';
        modal.style.zIndex = '9999';
        modal.style.display = 'flex';
        modal.style.flexDirection = 'column';
        modal.style.alignItems = 'center';
        modal.style.justifyContent = 'center';
        modal.innerHTML = `
            <div style="background:#222;padding:20px;border-radius:10px;max-width:900px;width:90vw;max-height:90vh;overflow:auto;">
                <h2>Admin Org Panel</h2>
                <button id="close-admin-org">Close</button>
                <h3>Orgs & Chat IDs</h3>
                <div id="admin-org-list"></div>
                <h3>Org/Admin Chat Log</h3>
                <div id="admin-org-chatlog" style="max-height:300px;overflow:auto;background:#181818;padding:10px;border-radius:5px;"></div>
            </div>
        `;
        document.body.appendChild(modal);
        document.getElementById('close-admin-org').onclick = function() {
            modal.remove();
            fetchNui('closeAdminOrg');
        };
    }
    renderAdminOrgList();
    updateAdminOrgChatLog();
}

function renderAdminOrgList() {
    const list = document.getElementById('admin-org-list');
    if (!list) return;
    list.innerHTML = Object.keys(adminOrgGangs).map(gang => {
        const g = adminOrgGangs[gang];
        return `<div><b>${gang}</b> — Chat ID: <code>${g.id}</code></div>`;
    }).join('');
}

function updateAdminOrgChatLog() {
    const log = document.getElementById('admin-org-chatlog');
    if (!log) return;
    log.innerHTML = adminOrgChats.slice(-100).map(e => {
        const direction = e.from === 'admin' ? '[ADMIN→ORG]' : '[ORG→ADMIN]';
        return `<div><span style="color:#f90">${direction}</span> <b>${e.gang||e.orgID}</b> <i>${e.sender}</i>: ${e.message}</div>`;
    }).join('');
}
