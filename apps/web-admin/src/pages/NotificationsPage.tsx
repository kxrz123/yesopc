import React from 'react';
import {
  Calendar,
  Card,
  Button,
  Dropdown,
  Input,
  Menu,
  Message,
  Tag,
  Tabs,
} from '@arco-design/web-react';
import {
  IconApps,
  IconArchive,
  IconEdit,
  IconEmpty,
  IconExport,
  IconFile,
  IconFire,
  IconIdcard,
  IconLanguage,
  IconNotification,
  IconPalette,
  IconSettings,
  IconRight,
  IconSearch,
  IconUser,
} from '@arco-design/web-react/icon';
import { useLocation, useNavigate } from 'react-router-dom';

const AUTH_KEY = 'yesopc_admin_logged_in';

type Notif = {
  id: string;
  title: string;
  timeText: string;
  content: string;
  read: boolean;
  archived: boolean;
};

const mockNotifs: Notif[] = [
  {
    id: 'n1',
    title: '系统更新',
    timeText: '7小时前',
    content: '已发布一项新功能（mock）：提升了整体性能与稳定性。',
    read: false,
    archived: false,
  },
  {
    id: 'n2',
    title: '草稿已保存',
    timeText: '3小时前',
    content: '你最近一次编辑的内容已保存为草稿（mock）。',
    read: true,
    archived: false,
  },
  {
    id: 'n3',
    title: '归档通知',
    timeText: '昨天',
    content: '这是一条已归档的通知（mock）。',
    read: true,
    archived: true,
  },
];

export const NotificationsPage: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const pathname = location.pathname;

  const [notifs, setNotifs] = React.useState<Notif[]>(mockNotifs);
  const [activeTab, setActiveTab] = React.useState<'all' | 'unread' | 'archived'>('all');

  const counts = React.useMemo(() => {
    const total = notifs.length;
    const unread = notifs.filter((n) => !n.read && !n.archived).length;
    const archived = notifs.filter((n) => n.archived).length;
    return { total, unread, archived };
  }, [notifs]);

  const profileMenu = (
    <Menu className="rail-avatar-menu" style={{ width: 220 }}>
      <Menu.Item key="profile">
        <IconIdcard style={{ marginRight: 10 }} />
        个人资料
      </Menu.Item>
      <Menu.Item key="archive">
        <IconArchive style={{ marginRight: 10 }} />
        已归档
      </Menu.Item>
      <Menu.Item key="language">
        <span className="rail-menu-title-with-arrow">
          <span>
            <IconLanguage style={{ marginRight: 10 }} />
            语言
          </span>
          <IconRight />
        </span>
      </Menu.Item>
      <Menu.Item key="theme">
        <span className="rail-menu-title-with-arrow">
          <span>
            <IconPalette style={{ marginRight: 10 }} />
            主题
          </span>
          <IconRight />
        </span>
      </Menu.Item>
      <Menu.Item key="settings">
        <IconSettings style={{ marginRight: 10 }} />
        设置
      </Menu.Item>
      <Menu.Item
        key="logout"
        onClick={() => {
          localStorage.removeItem(AUTH_KEY);
          Message.success('已退出登录');
          navigate('/login');
        }}
      >
        <IconExport style={{ marginRight: 10 }} />
        退出登录
      </Menu.Item>
    </Menu>
  );

  const tagFilters = ['YesOPC', '三创坛', '一起编', 'app开发'];
  const calendarLocale = {
    formatMonth: 'YYYY 年 MM 月',
    formatYear: 'YYYY 年',
  };

  const visibleNotifs = React.useMemo(() => {
    if (activeTab === 'unread') return notifs.filter((n) => !n.read && !n.archived);
    if (activeTab === 'archived') return notifs.filter((n) => n.archived);
    return notifs;
  }, [activeTab, notifs]);

  const markRead = (id: string) => {
    setNotifs((prev) => prev.map((n) => (n.id === id ? { ...n, read: true, archived: false } : n)));
  };

  const archive = (id: string) => {
    setNotifs((prev) => prev.map((n) => (n.id === id ? { ...n, archived: true, read: true } : n)));
  };

  return (
    <div className="admin-page">
      <aside className="admin-rail">
        <div className="rail-top">
          <button
            className={`rail-btn ${pathname === '/' ? 'rail-btn-active' : ''}`}
            type="button"
            title="首页"
            onClick={() => navigate('/')}
          >
            <IconApps style={{ fontSize: 22 }} />
          </button>
          <button
            className={`rail-btn ${pathname === '/files' ? 'rail-btn-active' : ''}`}
            type="button"
            title="文件"
            onClick={() => navigate('/files')}
          >
            <IconFile style={{ fontSize: 22 }} />
          </button>
          <button className="rail-btn" type="button" title="动态" onClick={() => navigate('/')}>
            <IconFire style={{ fontSize: 22 }} />
          </button>
          <button
            className={`rail-btn ${pathname === '/articles' ? 'rail-btn-active' : ''}`}
            type="button"
            title="编辑"
            onClick={() => navigate('/articles')}
          >
            <IconEdit style={{ fontSize: 22 }} />
          </button>
          <button
            className={`rail-btn ${pathname === '/notifications' ? 'rail-btn-active' : ''}`}
            type="button"
            title="通知"
            onClick={() => navigate('/notifications')}
          >
            <IconNotification style={{ fontSize: 22 }} />
          </button>
        </div>

        <div className="rail-avatar-anchor">
          <Dropdown
            trigger="click"
            droplist={profileMenu}
            position="tr"
            getPopupContainer={(node) =>
              (node.closest('.rail-avatar-anchor') as Element) || document.body
            }
          >
            <button className="rail-btn rail-bottom" type="button" title="我的">
              <IconUser style={{ fontSize: 22 }} />
            </button>
          </Dropdown>
        </div>
      </aside>

      <aside className="admin-sidebar">
        <div className="sidebar-search">
          <Input size="mini" allowClear prefix={<IconSearch />} placeholder="搜索备忘录" />
        </div>

        <div className="sidebar-calendar-wrap">
          <Calendar className="admin-mini-calendar" locale={calendarLocale} />
        </div>

        <div className="sidebar-label-block">
          <div className="sidebar-label-title">标签</div>
          <div className="sidebar-tags">
            {tagFilters.map((t) => (
              <Tag key={t} bordered={false} color="gray">
                #{t}
              </Tag>
            ))}
          </div>
        </div>
      </aside>

      <main className="admin-content">
        <Card className="composer-card" bordered>
          <div className="notification-title" style={{ fontSize: 14, fontWeight: 600, marginBottom: 12 }}>
            通知
          </div>

          <Tabs
            type="line"
            size="default"
            defaultActiveTab="all"
            activeTab={activeTab}
            onChange={(key) => setActiveTab(key as any)}
          >
            <Tabs.TabPane key="all" title={`全部 (${counts.total})`} />
            <Tabs.TabPane key="unread" title={`未读 (${counts.unread})`} />
            <Tabs.TabPane key="archived" title={`已归档 (${counts.archived})`} />
          </Tabs>

          {/* 用 activeTab 渲染内容，避免 Tabs children 结构不同导致类型问题 */}
          {visibleNotifs.length === 0 ? (
            <div
              style={{
                marginTop: 12,
                minHeight: 420,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <IconEmpty style={{ fontSize: 32, marginBottom: 8, opacity: 0.85 }} />
              <div style={{ fontSize: 12, color: '#9aa3af' }}>未找到任何数据。</div>
            </div>
          ) : (
            <div className="notification-list" style={{ marginTop: 12 }}>
              {visibleNotifs.map((n) => (
                <Card key={n.id} className="note-card" bordered style={{ marginBottom: 10 }}>
                  <div className="note-head">
                    <span className="note-time">{n.timeText}</span>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <Tag size="small" color={n.archived ? 'blue' : n.read ? 'gray' : 'orange'}>
                        {n.archived ? '已归档' : n.read ? '已读' : '未读'}
                      </Tag>
                      {!n.archived && !n.read ? (
                        <Button size="mini" type="secondary" onClick={() => markRead(n.id)}>
                          标为已读
                        </Button>
                      ) : null}
                      {!n.archived ? (
                        <Button size="mini" type="secondary" onClick={() => archive(n.id)}>
                          归档
                        </Button>
                      ) : null}
                    </div>
                  </div>
                  <div className="note-body">
                    <div style={{ fontWeight: 600, marginBottom: 6 }}>{n.title}</div>
                    {n.content}
                  </div>
                </Card>
              ))}
            </div>
          )}
        </Card>
      </main>
    </div>
  );
};

