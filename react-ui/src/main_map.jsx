import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';
import MapDebugApp from './MapDebugApp';

createRoot(document.getElementById('map-root')).render(
  <StrictMode>
    <MapDebugApp />
  </StrictMode>,
);
