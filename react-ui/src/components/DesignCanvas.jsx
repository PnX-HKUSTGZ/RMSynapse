import { useEffect, useState } from 'react';

const DESIGN_WIDTH = 1920;
const DESIGN_HEIGHT = 1080;

function viewportSize() {
  if (typeof window === 'undefined') {
    return { width: DESIGN_WIDTH, height: DESIGN_HEIGHT };
  }
  return {
    width: window.innerWidth || DESIGN_WIDTH,
    height: window.innerHeight || DESIGN_HEIGHT,
  };
}

function useDesignScale() {
  const [size, setSize] = useState(viewportSize);

  useEffect(() => {
    const updateSize = () => setSize(viewportSize());
    updateSize();
    window.addEventListener('resize', updateSize);
    window.visualViewport?.addEventListener('resize', updateSize);

    return () => {
      window.removeEventListener('resize', updateSize);
      window.visualViewport?.removeEventListener('resize', updateSize);
    };
  }, []);

  const scale = Math.min(size.width / DESIGN_WIDTH, size.height / DESIGN_HEIGHT);
  return Number.isFinite(scale) && scale > 0 ? scale : 1;
}

export default function DesignCanvas({ className = '', children }) {
  const scale = useDesignScale();

  return (
    <div
      className={`hud-design-canvas ${className}`.trim()}
      style={{ transform: `translate(-50%, -50%) scale(${scale})` }}
    >
      {children}
    </div>
  );
}
