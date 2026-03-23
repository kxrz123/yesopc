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
} from '@arco-design/web-react';
import { Empty } from '@arco-design/web-react';
import {
  IconApps,
  IconArchive,
  IconEdit,
  IconExport,
  IconFile,
  IconFire,
  IconIdcard,
  IconLanguage,
  IconLink,
  IconLocation,
  IconNotification,
  IconPalette,
  IconRight,
  IconSearch,
  IconUser,
  IconEmpty,
} from '@arco-design/web-react/icon';
import { useLocation, useNavigate } from 'react-router-dom';

const AUTH_KEY = 'yesopc_admin_logged_in';

type FileItem = {
  id: string;
  name: string;
  timeText: string;
  sizeText: string;
  readCount: number;
  archived: boolean;
};

const tagFilters = ['YesOPC', '三创坛', '一起编', 'app开发'];
const calendarLocale = {
  formatMonth: 'YYYY 年 MM 月',
  formatYear: 'YYYY 年',
};

const mockFiles: FileItem[] = [];

export const FilesPage: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const pathname = location.pathname;

  const [files] = React.useState<FileItem[]>(mockFiles);
  const [keyword, setKeyword] = React.useState('');

  const filtered = React.useMemo(() => {
    const kw = keyword.trim().toLowerCase();
    if (!kw) return files;
    return files.filter((f) => f.name.toLowerCase().includes(kw));
  }, [files, keyword]);

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
        <IconPalette style={{ marginRight: 10 }} />
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
              <span key={t} style={{ display: 'inline-block', marginRight: 6 }}>
                <Tag bordered={false} color="gray">
                  #{t}
                </Tag>
              </span>
            ))}
          </div>
        </div>
      </aside>

      <main className="admin-content">
        <Card className="composer-card" bordered>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              marginBottom: 12,
            }}
          >
            <div style={{ fontSize: 14, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 10 }}>
              <IconFile style={{ opacity: 0.8 }} />
              附件
            </div>

            <Input
              size="mini"
              allowClear
              prefix={<IconSearch />}
              placeholder="搜索"
              value={keyword}
              onChange={(v) => setKeyword(String(v))}
              style={{ width: 220 }}
            />
          </div>

          {filtered.length === 0 ? (
            <div
              style={{
                minHeight: 420,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#9aa3af',
              }}
            >
              <IconEmpty style={{ fontSize: 40, marginBottom: 8, opacity: 0.8 }} />
              <div style={{ fontSize: 12 }}>未找到任何数据</div>
            </div>
          ) : (
            <div className="note-list">
              {filtered.map((f) => (
                <Card key={f.id} className="note-card" bordered style={{ cursor: 'pointer' }}>
                  <div className="note-head">
                    <span className="note-time">{f.timeText}</span>
                    <Tag size="small" color={f.archived ? 'blue' : 'orange'}>
                      {f.archived ? '已归档' : '正常'}
                    </Tag>
                  </div>
                  <div className="note-body">
                    <div style={{ fontWeight: 600, marginBottom: 6 }}>{f.name}</div>
                    {f.sizeText} · 阅读量 {f.readCount}
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 10 }}>
                    <Button size="mini" type="secondary" onClick={() => Message.info('下载（mock）')}>
                      下载
                    </Button>
                    {!f.archived ? (
                      <Button size="mini" type="secondary" onClick={() => Message.info('归档（mock）')}>
                        归档
                      </Button>
                    ) : null}
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

