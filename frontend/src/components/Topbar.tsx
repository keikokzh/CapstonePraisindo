import React, { useState, useEffect } from 'react';
import { Moon, Sun } from 'lucide-react';

export const Topbar: React.FC = () => {
  const [isDark, setIsDark] = useState<boolean>(() => {
    return localStorage.getItem('theme') === 'dark';
  });

  useEffect(() => {
    if (isDark) {
      document.documentElement.setAttribute('data-theme', 'dark');
      localStorage.setItem('theme', 'dark');
    } else {
      document.documentElement.removeAttribute('data-theme');
      localStorage.setItem('theme', 'light');
    }
  }, [isDark]);

  const toggleTheme = () => setIsDark(prev => !prev);

  return (
    <header className="topbar">
      <div className="crumb">
        <span>Unit Registry</span>
        <span>›</span>
        <span>Statements &amp; Documents</span>
        <span>›</span>
        <b>Subscription per Produk Report</b>
      </div>
      <div className="topbar-right">
        <span className="badge badge-blue" style={{ textTransform: 'none', letterSpacing: 0 }}>
          Business Date belum tersedia
        </span>
        <button
          id="theme-toggle"
          className="btn btn-icon btn-outline"
          onClick={toggleTheme}
          title={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
          aria-label="Toggle theme"
        >
          {isDark ? <Sun /> : <Moon />}
        </button>
        <div className="avatar" title="Hazy Hazairin">
          HZ
        </div>
      </div>
    </header>
  );
};
