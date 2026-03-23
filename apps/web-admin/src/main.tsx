import React from 'react';
import ReactDOM from 'react-dom/client';
import '@arco-design/web-react/dist/css/arco.css';
import './styles.css';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { SocialNotesPage } from './pages/SocialNotesPage';
import { LoginPage } from './pages/LoginPage';
import { ArticlesPage } from './pages/ArticlesPage';
import { NotificationsPage } from './pages/NotificationsPage';
import { FilesPage } from './pages/FilesPage';

const AUTH_KEY = 'yesopc_admin_logged_in';

const isAuthed = () => localStorage.getItem(AUTH_KEY) === '1';

const ProtectedRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  if (!isAuthed()) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
};

const LoginRoute: React.FC = () => {
  if (isAuthed()) {
    return <Navigate to="/" replace />;
  }
  return <LoginPage />;
};

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <BrowserRouter>
      <Routes>
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <SocialNotesPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/articles"
          element={
            <ProtectedRoute>
              <ArticlesPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/notifications"
          element={
            <ProtectedRoute>
              <NotificationsPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/files"
          element={
            <ProtectedRoute>
              <FilesPage />
            </ProtectedRoute>
          }
        />
        <Route path="/login" element={<LoginRoute />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  </React.StrictMode>,
);

