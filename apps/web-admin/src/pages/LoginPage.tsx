import React from 'react';
import { Button, Card, Form, Grid, Input, Message, Typography } from '@arco-design/web-react';
import { useNavigate } from 'react-router-dom';

const { Row, Col } = Grid;
const { Text } = Typography;
const AUTH_KEY = 'yesopc_admin_logged_in';
const AUTH_TOKEN_KEY = 'yesopc_admin_token';
const apiBase = String(import.meta.env.VITE_API_BASE || '').replace(/\/$/, '');

export const LoginPage: React.FC = () => {
  const navigate = useNavigate();

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#f7f8fa',
      }}
    >
      <Card style={{ width: 420, borderRadius: 12, boxShadow: '0 8px 24px rgba(0,0,0,0.08)' }}>
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 10,
            marginBottom: 10,
          }}
        >
          <img
            src="/logo/logo14.jpg"
            alt="YesOPC Logo"
            style={{
              width: 48,
              height: 48,
              borderRadius: '50%',
              objectFit: 'cover',
              border: '1px solid #e5e6eb',
            }}
          />
          <div style={{ fontSize: 14, fontWeight: 400, color: '#1d2129', lineHeight: 1.2 }}>
            一人出发 结伴而行
          </div>
        </div>

        <Form
          layout="vertical"
          style={{ marginTop: 20 }}
          onSubmit={async (values) => {
            const username = String(values?.email ?? '').trim();
            const password = String(values?.password ?? '').trim();
            if (!username || !password) {
              Message.error('请输入账号和密码');
              return;
            }
            try {
              const path = '/api/v1/auth/login';
              const url = apiBase ? `${apiBase}${path}` : path;
              const res = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password }),
              });
              if (!res.ok) {
                const txt = await res.text().catch(() => '');
                throw new Error(txt || `登录失败: ${res.status}`);
              }
              const data = await res.json();
              const token = String(data?.token || '');
              if (!token) {
                throw new Error('登录成功但未返回 token');
              }
              localStorage.setItem(AUTH_KEY, '1');
              localStorage.setItem(AUTH_TOKEN_KEY, token);
              Message.success('登录成功');
              navigate('/');
            } catch (e) {
              Message.error(String(e));
            }
          }}
        >
          <Form.Item field="email" label="账号" rules={[{ required: true, message: '请输入账号' }]}>
            <Input placeholder="请输入邮箱或用户名" />
          </Form.Item>
          <Form.Item field="password" label="密码" rules={[{ required: true, message: '请输入密码' }]}>
            <Input.Password placeholder="请输入密码" />
          </Form.Item>
          <Row justify="space-between" align="center" style={{ marginBottom: 16 }}>
            <Col>
              <Text type="secondary" style={{ fontSize: 12 }}>
                使用 content-api 账号密码登录
              </Text>
            </Col>
          </Row>
          <Button type="primary" htmlType="submit" long>
            登录
          </Button>
        </Form>
      </Card>
    </div>
  );
};

