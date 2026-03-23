import React from 'react';
import {
  Calendar,
  Input,
  Button,
  Select,
  Tag,
  Space,
  Card,
  Dropdown,
  Menu,
  Message,
  Modal,
} from '@arco-design/web-react';
import dayjs from 'dayjs';
import ReactQuill from 'react-quill';
import 'react-quill/dist/quill.snow.css';
import {
  IconApps,
  IconFile,
  IconArchive,
  IconIdcard,
  IconLanguage,
  IconPalette,
  IconUpload,
  IconLink,
  IconLocation,
  IconMoreVertical,
  IconFullscreen,
  IconFullscreenExit,
  IconEdit,
  IconFire,
  IconNotification,
  IconUser,
  IconSearch,
  IconPlus,
  IconEmpty,
  IconSettings,
  IconExport,
  IconRight,
} from '@arco-design/web-react/icon';
import { useLocation, useNavigate } from 'react-router-dom';

const Option = Select.Option;
const AUTH_KEY = 'yesopc_admin_logged_in';
const AUTH_TOKEN_KEY = 'yesopc_admin_token';
const DRAFT_KEY = 'yesopc_article_draft';
const calendarLocale = {
  formatMonth: 'YYYY 年 MM 月',
  formatYear: 'YYYY 年',
};

/** 与 go-zero notes-api GET /api/v1/notes 返回字段一致 */
type ApiNote = {
  id: string;
  content_text: string;
  visibility: 'private' | 'public';
  created_at: string;
};

/** content-api GET /api/v1/tags 返回字段 */
type ApiTag = {
  id: string;
  name: string;
  created_at: string;
};

const formatRelativeTime = (iso: string) => {
  const date = new Date(iso);
  const diffMs = Date.now() - date.getTime();
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin <= 0) return '刚刚';
  if (diffMin < 60) return `${diffMin}分钟前`;
  const diffH = Math.floor(diffMin / 60);
  if (diffH < 24) return `${diffH}小时前`;
  const diffD = Math.floor(diffH / 24);
  if (diffD < 30) return `${diffD}天前`;
  return date.toLocaleDateString('zh-CN');
};

export const SocialNotesPage: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const pathname = location.pathname;
  const [isArticleEditorOpen, setIsArticleEditorOpen] = React.useState(false);
  const [articleHtml, setArticleHtml] = React.useState('');
  const [articleTitle, setArticleTitle] = React.useState('');
  const [coverImageUrl, setCoverImageUrl] = React.useState('');
  const [coverUploading, setCoverUploading] = React.useState(false);
  const [isArticleFullScreen, setIsArticleFullScreen] = React.useState(false);
  const quillRef = React.useRef<any>(null);
  const imageInputRef = React.useRef<HTMLInputElement | null>(null);
  const coverInputRef = React.useRef<HTMLInputElement | null>(null);

  /** 末尾无斜杠；空字符串时用同源 `/api/...`（开发走 Vite proxy） */
  const apiBase = String(import.meta.env.VITE_API_BASE || '').replace(/\/$/, '');
  const authHeaders = React.useCallback(() => {
    const token = localStorage.getItem(AUTH_TOKEN_KEY) || '';
    return token ? ({ Authorization: `Bearer ${token}` } as Record<string, string>) : {};
  }, []);

  const [noteContent, setNoteContent] = React.useState('');
  const [noteVisibility, setNoteVisibility] = React.useState<'private' | 'public'>('public');
  const [notes, setNotes] = React.useState<ApiNote[]>([]);
  const [notesLoading, setNotesLoading] = React.useState(false);
  const [tags, setTags] = React.useState<ApiTag[]>([]);
  // 选中日期（用于按天筛选 notes，格式：YYYY-MM-DD）
  const [selectedDateKey, setSelectedDateKey] = React.useState<string | null>(null);

  const toDateKeyLocal = (iso: string) => {
    const d = new Date(iso);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  };

  // notes 按日期聚合（本地时区：YYYY-MM-DD）
  const notesByDate = React.useMemo(() => {
    const m: Record<string, ApiNote[]> = {};
    for (const n of notes) {
      const key = toDateKeyLocal(n.created_at);
      if (!m[key]) m[key] = [];
      m[key].push(n);
    }
    return m;
  }, [notes]);

  const visibleNotes = React.useMemo(() => {
    if (!selectedDateKey) return notes;
    return notesByDate[selectedDateKey] || [];
  }, [notes, notesByDate, selectedDateKey]);

  const fetchNotes = React.useCallback(async () => {
    const path = '/api/v1/notes';
    const url = apiBase ? `${apiBase}${path}` : path;
    setNotesLoading(true);
    try {
      const res = await fetch(url, { method: 'GET', headers: authHeaders() });

      if (!res.ok) {
        const text = await res.text().catch(() => '');
        throw new Error(`拉取笔记失败: ${res.status} ${text}`);
      }

      const data = (await res.json()) as ApiNote[];
      setNotes(data);
    } catch (e) {
      Message.error(String(e));
    } finally {
      setNotesLoading(false);
    }
  }, [apiBase, authHeaders]);

  React.useEffect(() => {
    fetchNotes();
  }, [fetchNotes]);

  const fetchTags = React.useCallback(async () => {
    const path = '/api/v1/tags';
    const url = apiBase ? `${apiBase}${path}` : path;
    try {
      const res = await fetch(url, { method: 'GET', headers: authHeaders() });
      if (!res.ok) {
        const text = await res.text().catch(() => '');
        throw new Error(`拉取 tags 失败: ${res.status} ${text}`);
      }
      const data = (await res.json()) as ApiTag[];
      setTags(data);
    } catch (e) {
      // 标签只做展示，失败不影响保存/读取 notes
      // eslint-disable-next-line no-console
      console.error('fetchTags failed:', e);
    }
  }, [apiBase, authHeaders]);

  React.useEffect(() => {
    fetchTags();
  }, [fetchTags]);

  const dateRender = React.useCallback(
    (currentDate: any) => {
      const key = currentDate.format('YYYY-MM-DD');
      const count = notesByDate[key]?.length || 0;
      const isSelected = selectedDateKey === key;
      const isHasNotes = count > 0;
      return (
        <span
          className={[
            'notes-calendar-day',
            isHasNotes ? 'has-notes' : 'no-notes',
            isSelected ? 'selected' : '',
          ].join(' ')}
        >
          {isHasNotes ? (
            <span className="notes-calendar-day-tooltip">
              {key} 有{count}条备忘录
            </span>
          ) : null}
          {currentDate.date()}
        </span>
      );
    },
    [notesByDate, selectedDateKey],
  );

  const quillModules = React.useMemo(
    () => ({
      toolbar: {
        container: [
          [{ header: [1, 2, false] }],
          ['bold', 'italic', 'underline', 'strike'],
          [{ list: 'ordered' }, { list: 'bullet' }],
          ['link', 'image'],
        ],
        handlers: {
          image: () => {
            imageInputRef.current?.click();
          },
        },
      },
    }),
    [],
  );

  const quillFormats = React.useMemo(
    () => ['header', 'bold', 'italic', 'underline', 'strike', 'list', 'bullet', 'link', 'image'],
    [],
  );

  const handleLocalImageUpload: React.ChangeEventHandler<HTMLInputElement> = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = () => {
      const url = String(reader.result || '');
      const editor = quillRef.current?.getEditor?.();
      if (!editor) return;
      const range = editor.getSelection(true);
      const index = range ? range.index : 0;
      editor.insertEmbed(index, 'image', url, 'user');
      editor.setSelection(index + 1, 0, 'silent');
    };

    reader.readAsDataURL(file);

    // allow re-select the same file
    if (imageInputRef.current) imageInputRef.current.value = '';
  };

  const handleCoverUpload: React.ChangeEventHandler<HTMLInputElement> = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setCoverUploading(true);
    try {
      const form = new FormData();
      form.append('file', file);
      const path = '/api/v1/upload';
      const url = apiBase ? `${apiBase}${path}` : path;
      const res = await fetch(url, { method: 'POST', headers: authHeaders(), body: form });
      if (!res.ok) {
        const txt = await res.text().catch(() => '');
        throw new Error(`上传失败: ${res.status} ${txt}`);
      }
      const data = await res.json();
      setCoverImageUrl(data.url || '');
      Message.success('缩略图上传成功');
    } catch (err) {
      Message.error(String(err));
    } finally {
      setCoverUploading(false);
      if (coverInputRef.current) coverInputRef.current.value = '';
    }
  };

  const saveArticleToDB = React.useCallback(
    async (status: 'draft' | 'published') => {
      const title = articleTitle.trim() || '未命名文章';
      const bodyHtml = articleHtml.trim();
      if (!bodyHtml) {
        Message.info('请输入文章内容');
        return;
      }

      // 同时保留一份本地草稿（仅 draft 时）
      if (status === 'draft') {
        const payload = {
          title,
          html: bodyHtml,
          updatedAt: Date.now(),
        };
        localStorage.setItem(DRAFT_KEY, JSON.stringify(payload));
      }

      const path = '/api/v1/articles';
      const url = apiBase ? `${apiBase}${path}` : path;

      try {
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...authHeaders() },
          body: JSON.stringify({
            title,
            body_html: bodyHtml,
            cover_image: coverImageUrl,
            status,
          }),
        });

        if (!res.ok) {
          const errText = await res.text().catch(() => '');
          throw new Error(`保存失败: ${res.status} ${errText}`);
        }

        if (status === 'published') localStorage.removeItem(DRAFT_KEY);

        Message.success(status === 'draft' ? '已保存草稿（已落库）' : '已发布（已落库）');
        setIsArticleEditorOpen(false);
        setIsArticleFullScreen(false);
        setArticleHtml('');
        setArticleTitle('');
        setCoverImageUrl('');
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error('saveArticleToDB failed:', e);
        Message.error(String(e));
      }
    },
    [apiBase, articleHtml, articleTitle, coverImageUrl, authHeaders],
  );

  const handleSaveDraft = async () => {
    await saveArticleToDB('draft');
  };

  const onMenuClick = (key: string) => {
    if (key === 'logout') {
      localStorage.removeItem(AUTH_KEY);
      localStorage.removeItem(AUTH_TOKEN_KEY);
      Message.success('已退出登录');
      navigate('/login');
    }
  };

  const profileMenu = (
    <Menu
      className="rail-avatar-menu"
      style={{ width: 220 }}
    >
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
          onMenuClick('logout');
        }}
      >
        <IconExport style={{ marginRight: 10 }} />
        退出登录
      </Menu.Item>
    </Menu>
  );

  const onAddMenuClick = (key: string) => {
    if (key === 'upload') Message.info('触发：上传（mock）');
    if (key === 'link') Message.info('触发：链接备忘录（mock）');
    if (key === 'article') {
      setArticleHtml('');
      setArticleTitle('');
      setCoverImageUrl('');
      setIsArticleEditorOpen(true);
    }
    if (key === 'location') Message.info('触发：位置（mock）');
    if (key === 'more') Message.info('触发：更多（mock）');
  };

  const addMenu = (
    <Menu
      className="add-dropdown-menu"
      onClickMenuItem={(key) => onAddMenuClick(String(key))}
      style={{ width: 260 }}
    >
      <Menu.Item key="upload">
        <span className="add-menu-row">
          <IconUpload />
          上载
        </span>
      </Menu.Item>
      <Menu.Item key="link">
        <span className="add-menu-row">
          <IconLink />
          链接备忘录
        </span>
      </Menu.Item>
      <Menu.Item key="location">
        <span className="add-menu-row">
          <IconLocation />
          位置
        </span>
      </Menu.Item>
      <Menu.Item key="article">
        <span className="add-menu-row">
          <IconFile />
          添加文章
        </span>
      </Menu.Item>
      <Menu.Item key="more">
        <span className="add-menu-row add-menu-row-right">
          <span className="add-menu-row-left">
            <IconMoreVertical />
            更多
          </span>
          <IconRight />
        </span>
      </Menu.Item>
      <Menu.Item key="command" disabled className="add-menu-shortcut">
        按下 `/` 输入命令
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
          <Input
            size="mini"
            allowClear
            prefix={<IconSearch />}
            placeholder="搜索备忘录"
          />
        </div>

        <div className="sidebar-calendar-wrap">
          <Calendar
            className="admin-mini-calendar"
            locale={calendarLocale}
            allowSelect
            value={selectedDateKey ? dayjs(selectedDateKey) : undefined}
            onChange={(d: any) => {
              setSelectedDateKey(d.format('YYYY-MM-DD'));
            }}
            dateRender={dateRender}
          />
        </div>

        <div className="sidebar-label-block">
          <div className="sidebar-label-title">标签</div>
          <div className="sidebar-tags">
            {tags.map((t) => (
              <Tag key={t.id} bordered={false} color="gray">
                #{t.name}
              </Tag>
            ))}
          </div>
        </div>
      </aside>

      <main className="admin-content admin-content-feed">
        <Card className="composer-card" bordered>
          <div className="composer-row">
            <Input.TextArea
              autoSize={{ minRows: 3, maxRows: 5 }}
              placeholder="此刻的想法..."
              className="composer-textarea"
              value={noteContent}
              onChange={(v) => setNoteContent(String(v))}
            />
          </div>
          <div className="composer-actions">
            <div className="add-button-anchor">
              <Dropdown
                trigger="click"
                droplist={addMenu}
                position="bl"
                getPopupContainer={(node) =>
                  (node.closest('.add-button-anchor') as Element) || document.body
                }
              >
                <Button size="mini" icon={<IconPlus />} />
              </Dropdown>
            </div>
            <Space size={8}>
              <Select
                size="mini"
                value={noteVisibility}
                onChange={(v) => setNoteVisibility(String(v) as 'private' | 'public')}
                style={{ width: 86 }}
              >
                <Option value="private">私有</Option>
                <Option value="public">公开</Option>
              </Select>
              <Button
                size="mini"
                type="primary"
                onClick={async () => {
                  const text = noteContent.trim();
                  if (!text) {
                    Message.info('请输入内容后再保存');
                    return;
                  }
                  try {
                    const path = '/api/v1/notes';
                    const url = apiBase ? `${apiBase}${path}` : path;
                    const res = await fetch(url, {
                      method: 'POST',
                      headers: { 'Content-Type': 'application/json' },
                      body: JSON.stringify({
                        visibility: noteVisibility,
                        content_text: text,
                      }),
                    });

                    if (!res.ok) {
                      const errText = await res.text().catch(() => '');
                      throw new Error(`保存失败: ${res.status} ${errText}`);
                    }

                    const saved = (await res.json().catch(() => null)) as
                      | { created_at?: string }
                      | null;

                    Message.success('已保存');
                    setNoteContent('');
                    await fetchNotes();
                    if (saved?.created_at) {
                      setSelectedDateKey(toDateKeyLocal(saved.created_at));
                    }
                    await fetchTags();
                  } catch (e) {
                    // eslint-disable-next-line no-console
                    console.error('save note failed:', e);
                    Message.error(
                      String(e) +
                        '（请确认已启动 services/content-api 并配置 DATABASE_URL / DEFAULT_NOTES_USER_ID）',
                    );
                  }
                }}
              >
                保存
              </Button>
            </Space>
          </div>
        </Card>

        {selectedDateKey ? (
          <div className="selected-date-row selected-date-row-between">
            <span className="selected-date-pill">
              <span className="selected-date-pill-icon" aria-hidden>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <rect x="4.5" y="6.5" width="15" height="14" rx="2.5" stroke="currentColor" strokeWidth="1.7" />
                  <path d="M8 3.8V8.2" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
                  <path d="M16 3.8V8.2" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
                  <path d="M4.5 10.2H19.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
                </svg>
              </span>
              {selectedDateKey}
              <button
                type="button"
                className="selected-date-pill-close"
                aria-label="取消日期筛选"
                onClick={() => setSelectedDateKey(null)}
              >
                ×
              </button>
            </span>
          </div>
        ) : null}

        {notesLoading ? (
          <div className="empty-wrap">
            <div className="empty-text" style={{ fontSize: 12 }}>
              加载中...
            </div>
          </div>
        ) : visibleNotes.length === 0 ? (
          <div className="empty-wrap">
            <IconEmpty className="empty-icon" />
            <div className="empty-text">未找到匹配的数据。</div>
          </div>
        ) : (
          <div className="note-list">
            {visibleNotes.map((note) => (
              <Card key={note.id} className="note-card" bordered>
                <div className="note-head">
                  <span className="note-time">{formatRelativeTime(note.created_at)}</span>
                  <Button
                    type="text"
                    size="mini"
                    className="note-more"
                    icon={<IconMoreVertical />}
                  />
                </div>
                <div className="note-body">{note.content_text}</div>
              </Card>
            ))}
          </div>
        )}
      </main>

      <Modal
        wrapClassName={isArticleFullScreen ? 'article-modal-fullscreen' : undefined}
        title={
          <div className="article-modal-title">
            <span>添加文章</span>
            <Button
              size="mini"
              className="article-modal-fullscreen-btn"
              icon={isArticleFullScreen ? <IconFullscreenExit /> : <IconFullscreen />}
              onClick={(e) => {
                e.stopPropagation();
                setIsArticleFullScreen((v) => !v);
              }}
            />
          </div>
        }
        visible={isArticleEditorOpen}
        footer={(cancelButtonNode, okButtonNode) => (
          <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: 12, width: '100%' }}>
            <div>{cancelButtonNode}</div>
            <Button
              type="secondary"
              onClick={handleSaveDraft}
            >
              保存草稿
            </Button>
            <div>{okButtonNode}</div>
          </div>
        )}
        onCancel={() => {
          setIsArticleEditorOpen(false);
          setIsArticleFullScreen(false);
          setArticleHtml('');
          setArticleTitle('');
          setCoverImageUrl('');
        }}
        onOk={async () => {
          // Arco 在 onOk 触发后会执行 close；这里把 close 逻辑放在保存成功后。
          // 若保存失败，弹窗保持可见（saveArticleToDB 内不关闭）。
          await saveArticleToDB('published');
        }}
        okText="发布"
        cancelText="取消"
        style={
          isArticleFullScreen
            ? { width: '100vw', height: '100vh', top: 0, borderRadius: 0 }
            : { width: 760 }
        }
      >
        <div className="cover-upload-row" style={{ marginBottom: 12, display: 'flex', alignItems: 'center', gap: 12 }}>
          <input
            ref={coverInputRef}
            type="file"
            accept="image/*"
            style={{ display: 'none' }}
            onChange={handleCoverUpload}
          />
          <Button
            size="small"
            icon={<IconUpload />}
            loading={coverUploading}
            onClick={() => coverInputRef.current?.click()}
          >
            {coverImageUrl ? '更换缩略图（单图）' : '上传缩略图（单图）'}
          </Button>
          {coverImageUrl ? (
            <div style={{ position: 'relative' }}>
              <img src={coverImageUrl} alt="封面" style={{ width: 120, height: 68, objectFit: 'cover', borderRadius: 8, border: '1px solid #e5e7eb' }} />
              <Button size="mini" style={{ position: 'absolute', top: 2, right: 2 }} onClick={() => setCoverImageUrl('')}>×</Button>
            </div>
          ) : null}
          <Input
            size="small"
            placeholder="或粘贴单图缩略图 URL"
            style={{ flex: 1, maxWidth: 360 }}
            value={coverImageUrl}
            onChange={(v) => setCoverImageUrl(String(v).trim())}
          />
        </div>
        <Input
          className="article-title-input"
          placeholder="请输入文章标题"
          value={articleTitle}
          onChange={(v) => setArticleTitle(String(v))}
        />
        <input
          ref={imageInputRef}
          type="file"
          accept="image/*"
          style={{ display: 'none' }}
          onChange={handleLocalImageUpload}
        />
        <div className="article-editor">
          <ReactQuill
            key={isArticleFullScreen ? 'article-editor-full' : 'article-editor-normal'}
            ref={quillRef}
            theme="snow"
            value={articleHtml}
            onChange={setArticleHtml}
            modules={quillModules}
            formats={quillFormats}
          />
        </div>
      </Modal>
    </div>
  );
};

