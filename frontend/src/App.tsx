import React from 'react';
import { Sidebar } from './components/Sidebar';
import { Topbar } from './components/Topbar';
import { SubscriptionReportPage } from './pages/SubscriptionReportPage';

export const App: React.FC = () => {
  const [hash, setHash] = React.useState(window.location.hash || '#subscription-by-product');

  React.useEffect(() => {
    const handleHashChange = () => {
      setHash(window.location.hash || '#subscription-by-product');
    };
    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, []);

  const isSubscriptionPage =
    hash === '#subscription-by-product' ||
    hash === '#subscription' ||
    hash === '' ||
    hash === '#';

  return (
    <div className="app-wrapper">
      <Sidebar currentHash={hash} />
      <div className="main-col">
        <Topbar />
        {isSubscriptionPage ? (
          <SubscriptionReportPage />
        ) : (
          <div className="page-body state-container">
            <h2 style={{ color: 'var(--text-secondary)' }}>Fitur Belum Tersedia</h2>
            <p>Halaman ini belum diimplementasikan dalam versi demo.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default App;
