import React from 'react';
import {
  Calendar,
  Card,
  Button,
  Dropdown,
  Input,
  Menu,
  Message,
  Modal,
  Pagination,
  Select,
  Space,
  Tag,
} from '@arco-design/web-react';
import ReactQuill from 'react-quill';
import 'react-quill/dist/quill.snow.css';
import {
  IconApps,
  IconArchive,
  IconEdit,
  IconEmpty,
  IconExport,
  IconFile,
  IconFire,
  IconFullscreen,
  IconFullscreenExit,
  IconIdcard,
  IconLanguage,
  IconLink,
  IconLocation,
  IconMoreVertical,
  IconNotification,
  IconPalette,
  IconPlus,
  IconSearch,
  IconSettings,
  IconRight,
  IconUpload,
  IconUser,
} from '@arco-design/web-react/icon';
import { useLocation, useNavigate } from 'react-router-dom';

const Option = Select.Option;
const AUTH_KEY = 'yesopc_admin_logged_in';
const AUTH_TOKEN_KEY = 'yesopc_admin_token';
const DRAFT_KEY = 'yesopc_article_draft';

const tagFilters = ['YesOPC', '三创坛', '一起编', 'app开发'];
const calendarLocale = {
  formatMonth: 'YYYY 年 MM 月',
  formatYear: 'YYYY 年',
};

type Article = {
  id: string;
  title: string;
  timeText: string;
  html: string;
  coverImage: string;
  status: 'draft' | 'published';
  readCount: number;
};

type ApiArticle = {
  id: string;
  title: string;
  body_html: string;
  cover_image: string;
  status: 'draft' | 'published';
  published_at: string | null;
  read_count: number;
  created_at: string;
  updated_at: string;
};

type listArticlesResp = {
  items: ApiArticle[];
  total: number;
  page: number;
  page_size: number;
  status?: 'draft' | 'published';
};

const stripHtml = (html: string) =>
  html
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 90);

// 从 Quill 的 body_html 中提取第一张图片 src，用于列表缩略图展示
const extractFirstImageSrc = (html: string): string | null => {
  if (!html) return null;
  const m =
    html.match(/<img[^>]+src=(?:"([^"]+)"|'([^']+)'|([^ >]+))/i) ||
    html.match(/<img[^>]+data-src=(?:"([^"]+)"|'([^']+)'|([^ >]+))/i);
  const src = m?.[1] || m?.[2] || m?.[3] || null;
  if (!src) return null;
  return String(src);
};

const DEFAULT_THUMB_SRC = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(
  `<svg xmlns="http://www.w3.org/2000/svg" width="92" height="44" viewBox="0 0 92 44">
    <rect x="0" y="0" width="92" height="44" rx="8" fill="#f0f2f5"/>
    <path d="M16 32l18-18 14 14 9-9 9 13H16z" fill="#d7dde6"/>
    <circle cx="28" cy="17" r="4" fill="#d7dde6"/>
  </svg>`,
)}`;

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

/** 末尾无斜杠；空字符串时用同源 `/api/...`（开发走 Vite proxy） */
const apiBase = String(import.meta.env.VITE_API_BASE || '').replace(/\/$/, '');
const authHeaders = () => {
  const token = localStorage.getItem(AUTH_TOKEN_KEY) || '';
  return token ? ({ Authorization: `Bearer ${token}` } as Record<string, string>) : {};
};

export const ArticlesPage: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const pathname = location.pathname;

  const draftPageSize = 5;
  const publishedPageSize = 5;

  const [draftArticles, setDraftArticles] = React.useState<Article[]>([]);
  const [publishedArticles, setPublishedArticles] = React.useState<Article[]>([]);

  const [draftArticlesLoading, setDraftArticlesLoading] = React.useState(false);
  const [publishedArticlesLoading, setPublishedArticlesLoading] = React.useState(false);

  const [draftPage, setDraftPage] = React.useState(1);
  const [publishedPage, setPublishedPage] = React.useState(1);

  const [draftTotal, setDraftTotal] = React.useState(0);
  const [publishedTotal, setPublishedTotal] = React.useState(0);

  const [isArticleEditorOpen, setIsArticleEditorOpen] = React.useState(false);
  const [editorMode, setEditorMode] = React.useState<'add' | 'edit'>('add');
  const [selectedArticleId, setSelectedArticleId] = React.useState<string | null>(null);

  const [articleHtml, setArticleHtml] = React.useState('');
  const [articleTitle, setArticleTitle] = React.useState('');
  const [isArticleFullScreen, setIsArticleFullScreen] = React.useState(false);
  const [coverImageUrl, setCoverImageUrl] = React.useState('');
  const [coverUploading, setCoverUploading] = React.useState(false);
  const coverInputRef = React.useRef<HTMLInputElement | null>(null);

  const quillRef = React.useRef<any>(null);
  const imageInputRef = React.useRef<HTMLInputElement | null>(null);

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
      Message.success('封面图上传成功');
    } catch (err) {
      Message.error(String(err));
    } finally {
      setCoverUploading(false);
      if (coverInputRef.current) coverInputRef.current.value = '';
    }
  };

  const fetchArticlesByStatus = React.useCallback(
    async (status: 'draft' | 'published', page: number, pageSize: number) => {
      const path = '/api/v1/articles';
      const urlBase = apiBase ? `${apiBase}${path}` : path;
      const url = `${urlBase}?status=${encodeURIComponent(status)}&page=${page}&page_size=${pageSize}`;

      if (status === 'draft') setDraftArticlesLoading(true);
      if (status === 'published') setPublishedArticlesLoading(true);

      try {
        const res = await fetch(url, { method: 'GET', headers: authHeaders() });
        if (!res.ok) {
          const text = await res.text().catch(() => '');
          throw new Error(`拉取文章失败: ${res.status} ${text}`);
        }

        const data = (await res.json()) as listArticlesResp;
        const items = (data?.items || []).map((a) => ({
          id: a.id,
          title: a.title,
          timeText: formatRelativeTime(a.created_at),
          html: a.body_html,
          coverImage: a.cover_image || '',
          status: a.status,
          readCount: Number(a.read_count || 0),
        }));

        if (status === 'draft') {
          setDraftArticles(items);
          setDraftTotal(Number(data?.total || 0));
        } else {
          setPublishedArticles(items);
          setPublishedTotal(Number(data?.total || 0));
        }
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error('fetchArticlesByStatus failed:', e);
        Message.error(String(e));
      } finally {
        if (status === 'draft') setDraftArticlesLoading(false);
        if (status === 'published') setPublishedArticlesLoading(false);
      }
    },
    [apiBase],
  );

  React.useEffect(() => {
    fetchArticlesByStatus('draft', draftPage, draftPageSize);
  }, [fetchArticlesByStatus, draftPage, draftPageSize]);

  React.useEffect(() => {
    fetchArticlesByStatus('published', publishedPage, publishedPageSize);
  }, [fetchArticlesByStatus, publishedPage, publishedPageSize]);

  const saveArticleToDB = React.useCallback(
    async (status: 'draft' | 'published') => {
      const title = (articleTitle || '').trim() || '未命名文章';
      const bodyHtml = (articleHtml || '').trim();
      if (!bodyHtml) {
        Message.info('请输入文章内容');
        return;
      }

      const path = '/api/v1/articles';
      const url = apiBase ? `${apiBase}${path}` : path;
      const id = editorMode === 'edit' ? selectedArticleId : '';

      try {
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...authHeaders() },
          body: JSON.stringify({
            id,
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

        Message.success(status === 'draft' ? '已保存草稿（已落库）' : '已发布文章（已落库）');
        await Promise.all([
          fetchArticlesByStatus('draft', draftPage, draftPageSize),
          fetchArticlesByStatus('published', publishedPage, publishedPageSize),
        ]);

        setIsArticleEditorOpen(false);
        setIsArticleFullScreen(false);
        setSelectedArticleId(null);
        setArticleHtml('');
        setArticleTitle('');
        setCoverImageUrl('');
        setEditorMode('add');
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error('saveArticleToDB failed:', e);
        Message.error(String(e));
      }
    },
    [
      apiBase,
      articleHtml,
      articleTitle,
      coverImageUrl,
      editorMode,
      selectedArticleId,
      fetchArticlesByStatus,
      draftPage,
      draftPageSize,
      publishedPage,
      publishedPageSize,
    ],
  );

  const handleSaveDraft = async () => {
    await saveArticleToDB('draft');
  };

  const openAddEditor = () => {
    setEditorMode('add');
    setSelectedArticleId(null);
    setArticleTitle('');
    setArticleHtml('');
    setCoverImageUrl('');
    setIsArticleFullScreen(false);
    setIsArticleEditorOpen(true);
  };

  const openEditEditor = (article: Article) => {
    setEditorMode('edit');
    setSelectedArticleId(article.id);
    setArticleTitle(article.title);
    setArticleHtml(article.html);
    setCoverImageUrl(article.coverImage || '');
    setIsArticleFullScreen(false);
    setIsArticleEditorOpen(true);
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
    if (key === 'location') Message.info('触发：位置（mock）');
    if (key === 'more') Message.info('触发：更多（mock）');
    if (key === 'article') openAddEditor();
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
          <IconEdit />
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

      <main className="admin-content admin-content-feed">
        <Card className="composer-card" bordered>
          <div className="composer-row">
            <Input.TextArea
              autoSize={{ minRows: 3, maxRows: 5 }}
              placeholder="写点文章内容（mock）..."
              className="composer-textarea"
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
              <Select size="mini" defaultValue="private" style={{ width: 86 }}>
                <Option value="private">私有</Option>
                <Option value="public">公开</Option>
              </Select>
              <Button size="mini" type="primary" onClick={openAddEditor}>
                保存
              </Button>
            </Space>
          </div>
        </Card>

        {draftArticlesLoading && publishedArticlesLoading ? (
          <div className="empty-wrap">
            <div className="empty-text" style={{ fontSize: 12 }}>
              加载中...
            </div>
          </div>
        ) : draftArticles.length === 0 && publishedArticles.length === 0 ? (
          <div className="empty-wrap">
            <IconEmpty className="empty-icon" />
            <div className="empty-text">未找到匹配的数据。</div>
          </div>
        ) : (
          <div className="note-list">
            <div className="articles-section-title">草稿箱（{draftTotal}）</div>
            {draftArticles.length === 0 ? (
              <div className="articles-section-empty">暂无草稿</div>
            ) : (
              draftArticles.map((a) => {
                const thumb = a.coverImage || extractFirstImageSrc(a.html) || DEFAULT_THUMB_SRC;
                return (
                  <Card
                    key={a.id}
                    className="note-card"
                    bordered
                    style={{ cursor: 'pointer' }}
                    onClick={() => openEditEditor(a)}
                  >
                    <div className="note-head">
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
                        <span className="note-time">{a.timeText}</span>
                        <Tag size="small" color="orange">
                          草稿
                        </Tag>
                        <span className="note-time">阅读量 {a.readCount}</span>
                      </div>
                      <Button
                        type="text"
                        size="mini"
                        className="note-more"
                        icon={<IconMoreVertical />}
                        onClick={(e) => {
                          e.stopPropagation();
                          Message.info('更多（mock）');
                        }}
                      />
                    </div>
                    <div className="note-body">
                      <div className="article-card-top">
                        <img
                          className="article-thumb"
                          src={thumb}
                          alt=""
                          loading="lazy"
                        />
                        <div className="article-right">
                          <div className="article-title">{a.title}</div>
                          <div className="article-snippet">{stripHtml(a.html)}</div>
                        </div>
                      </div>
                    </div>
                  </Card>
                );
              })
            )}

            <div className="articles-pagination-wrap">
              <Pagination
                size="mini"
                current={draftPage}
                pageSize={draftPageSize}
                total={draftTotal}
                hideOnSinglePage
                showTotal={(total) => `共 ${total} 条`}
                onChange={(page) => setDraftPage(page)}
              />
            </div>

            <div className="articles-section-title" style={{ marginTop: 14 }}>
              已发布（{publishedTotal}）
            </div>
            {publishedArticles.length === 0 ? (
              <div className="articles-section-empty">暂无已发布文章</div>
            ) : (
              publishedArticles.map((a) => {
                const thumb = a.coverImage || extractFirstImageSrc(a.html) || DEFAULT_THUMB_SRC;
                return (
                  <Card
                    key={a.id}
                    className="note-card"
                    bordered
                    style={{ cursor: 'pointer' }}
                    onClick={() => openEditEditor(a)}
                  >
                    <div className="note-head">
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
                        <span className="note-time">{a.timeText}</span>
                        <Tag size="small" color="green">
                          已发布
                        </Tag>
                        <span className="note-time">阅读量 {a.readCount}</span>
                      </div>
                      <Button
                        type="text"
                        size="mini"
                        className="note-more"
                        icon={<IconMoreVertical />}
                        onClick={(e) => {
                          e.stopPropagation();
                          Message.info('更多（mock）');
                        }}
                      />
                    </div>
                    <div className="note-body">
                      <div className="article-card-top">
                        <img
                          className="article-thumb"
                          src={thumb}
                          alt=""
                          loading="lazy"
                        />
                        <div className="article-right">
                          <div className="article-title">{a.title}</div>
                          <div className="article-snippet">{stripHtml(a.html)}</div>
                        </div>
                      </div>
                    </div>
                  </Card>
                );
              })
            )}

            <div className="articles-pagination-wrap">
              <Pagination
                size="mini"
                current={publishedPage}
                pageSize={publishedPageSize}
                total={publishedTotal}
                hideOnSinglePage
                showTotal={(total) => `共 ${total} 条`}
                onChange={(page) => setPublishedPage(page)}
              />
            </div>
          </div>
        )}
      </main>

      <Modal
        wrapClassName={isArticleFullScreen ? 'article-modal-fullscreen' : undefined}
        title={
          <div className="article-modal-title">
            <span>{editorMode === 'edit' ? '编辑文章' : '添加文章'}</span>
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
          <div
            style={{
              display: 'flex',
              justifyContent: 'flex-end',
              alignItems: 'center',
              gap: 12,
              width: '100%',
            }}
          >
            <div>{cancelButtonNode}</div>
            <Button type="secondary" onClick={handleSaveDraft}>
              保存草稿
            </Button>
            <div>{okButtonNode}</div>
          </div>
        )}
        onCancel={() => {
          setIsArticleEditorOpen(false);
          setIsArticleFullScreen(false);
          setSelectedArticleId(null);
          setArticleHtml('');
          setArticleTitle('');
          setCoverImageUrl('');
          setEditorMode('add');
        }}
        onOk={async () => {
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
            // 由于 Modal 切换/高度变化，Quill 有时需要强制重建以保证渲染不塌陷
            key={`${isArticleFullScreen ? 'full' : 'normal'}-${editorMode}-${selectedArticleId || 'add'}`}
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

