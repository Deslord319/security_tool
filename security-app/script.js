// HarmonyOS 安全管理中心交互脚本

// 页面导航历史
let pageHistory = ['dashboard'];

// 主导航页面映射
const mainNavPages = ['dashboard', 'firewall', 'log-manage', 'peripheral-manage', 'identity', 'tool-settings'];

// 显示指定页面
function showPage(pageId) {
    // 隐藏所有页面
    document.querySelectorAll('.page').forEach(page => {
        page.classList.remove('active');
    });
    
    // 显示目标页面
    const targetPage = document.getElementById(pageId);
    if (targetPage) {
        targetPage.classList.add('active');
        pageHistory.push(pageId);
    }
    
    // 更新侧边栏选中状态
    if (mainNavPages.includes(pageId)) {
        document.querySelectorAll('.nav-item').forEach(item => {
            item.classList.remove('active');
            if (item.dataset.page === pageId) {
                item.classList.add('active');
            }
        });
    }
    
    // 滚动到顶部
    document.querySelector('.content-area').scrollTop = 0;
}

// 返回上一页
function goBack() {
    if (pageHistory.length > 1) {
        pageHistory.pop();
        const prevPage = pageHistory[pageHistory.length - 1];
        
        document.querySelectorAll('.page').forEach(page => {
            page.classList.remove('active');
        });
        
        const targetPage = document.getElementById(prevPage);
        if (targetPage) {
            targetPage.classList.add('active');
        }
        
        // 更新侧边栏
        if (mainNavPages.includes(prevPage)) {
            document.querySelectorAll('.nav-item').forEach(item => {
                item.classList.remove('active');
                if (item.dataset.page === prevPage) {
                    item.classList.add('active');
                }
            });
        }
    }
}

// 切换防火墙
function toggleFirewall() {
    const checkbox = document.getElementById('firewall-switch');
    if (checkbox.checked) {
        showModal('auth-modal');
        checkbox.checked = false;
    } else {
        updateFirewallStatus(false);
    }
}

// 更新防火墙状态
function updateFirewallStatus(enabled) {
    const statEl = document.getElementById('stat-firewall');
    if (statEl) {
        statEl.textContent = enabled ? '已开启' : '已关闭';
        statEl.style.color = enabled ? '#34C759' : '';
    }
}

// 确认认证
function confirmAuth() {
    const password = document.getElementById('auth-password').value;
    if (password) {
        document.getElementById('firewall-switch').checked = true;
        closeModal('auth-modal');
        updateFirewallStatus(true);
        showToast('防火墙已开启');
    } else {
        showToast('请输入密码');
    }
}

// 弹窗管理
function showModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.add('active');
    }
}

function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.remove('active');
    }
}

// 切换密码可见性
function togglePwdVisibility(inputId, btn) {
    const input = document.getElementById(inputId);
    const icon = btn.querySelector('i');
    
    if (input.type === 'password') {
        input.type = 'text';
        icon.className = 'fas fa-eye-slash';
    } else {
        input.type = 'password';
        icon.className = 'fas fa-eye';
    }
}

// Toast 提示
function showToast(message) {
    const toast = document.getElementById('toast');
    const toastText = document.getElementById('toast-text');
    toastText.textContent = message;
    toast.classList.add('show');
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 2500);
}

// 日志管理功能
function refreshLogs() {
    showToast('日志已刷新');
}

function exportLogs() {
    showToast('日志导出中...');
}

function clearLogs() {
    if (confirm('确定要清除所有日志记录吗？此操作不可撤销。')) {
        const tbody = document.getElementById('log-table-body');
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;padding:48px;color:rgba(0,0,0,0.4);">暂无审计事件</td></tr>';
        }
        showToast('日志已清除');
    }
}

function filterLogs() {
    showToast('筛选条件已应用');
}

// 防火墙规则管理
function addFirewallRule() {
    closeModal('add-rule-modal');
    showToast('防火墙规则已添加');
}

// 身份鉴别配置保存
function saveIdentityConfig() {
    showToast('身份鉴别配置已保存');
}

// 工具设置保存
function saveToolSettings() {
    showToast('工具设置已保存');
}

// 初始化
document.addEventListener('DOMContentLoaded', () => {
    // 侧边栏导航点击
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', () => {
            const pageId = item.dataset.page;
            showPage(pageId);
        });
    });
    
    // Tab切换
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const tabId = btn.dataset.tab;
            const container = btn.closest('.tab-container') || btn.parentElement;
            
            // 更新Tab按钮状态
            container.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            
            // 更新Tab内容
            const tabContent = container.querySelector('.tab-content');
            if (tabContent) {
                tabContent.querySelectorAll('.tab-panel').forEach(panel => {
                    panel.classList.remove('active');
                });
                const targetPanel = document.getElementById(tabId);
                if (targetPanel) {
                    targetPanel.classList.add('active');
                }
            }
        });
    });

    // 点击弹窗外部关闭
    document.querySelectorAll('.modal').forEach(modal => {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.classList.remove('active');
            }
        });
    });

    // ESC 关闭弹窗
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            document.querySelectorAll('.modal.active').forEach(modal => {
                modal.classList.remove('active');
            });
        }
    });
});
