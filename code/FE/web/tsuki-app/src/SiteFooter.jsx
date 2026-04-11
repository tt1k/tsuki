function SiteFooter({ productName, className = "" }) {
  const footerClassName = className ? `footer-mark ${className}` : "footer-mark";

  return (
    <footer className={footerClassName}>
      <span className="footer-brand">{productName}</span>
      <div className="footer-social">
        <a
          className="footer-link"
          href="https://github.com/tt1k"
          target="_blank"
          rel="noreferrer"
          aria-label="GitHub: tt1k"
          title="GitHub: tt1k"
        >
          <svg className="footer-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 0C5.37 0 0 5.37 0 12c0 5.3 3.44 9.8 8.2 11.38.6.12.82-.26.82-.58 0-.28-.01-1.04-.02-2.04-3.34.72-4.04-1.61-4.04-1.61-.54-1.39-1.33-1.75-1.33-1.75-1.09-.74.08-.72.08-.72 1.2.08 1.84 1.24 1.84 1.24 1.08 1.83 2.82 1.3 3.5 1 .1-.78.42-1.3.76-1.6-2.67-.3-5.46-1.33-5.46-5.94 0-1.31.47-2.38 1.24-3.22-.12-.3-.54-1.53.12-3.18 0 0 1.02-.33 3.34 1.23a11.7 11.7 0 0 1 6.08 0c2.32-1.56 3.34-1.23 3.34-1.23.67 1.65.25 2.88.12 3.18.78.84 1.24 1.9 1.24 3.22 0 4.62-2.8 5.63-5.47 5.93.43.37.82 1.1.82 2.23 0 1.61-.01 2.9-.01 3.29 0 .32.21.7.83.58A12 12 0 0 0 24 12c0-6.63-5.37-12-12-12" />
          </svg>
        </a>
        <span className="footer-sep" aria-hidden="true">
          •
        </span>
        <a
          className="footer-link"
          href="https://x.com/zenlee1024"
          target="_blank"
          rel="noreferrer"
          aria-label="X: @zenlee1024"
          title="X: @zenlee1024"
        >
          <svg className="footer-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M18.244 2H21.5l-7.12 8.14L22.5 22h-6.35l-4.97-6.5L5.5 22H2.24l7.62-8.71L1.5 2H8l4.49 5.92L18.244 2zm-1.11 18h1.76L7.96 3.9H6.08L17.13 20z" />
          </svg>
        </a>
      </div>
    </footer>
  );
}

export default SiteFooter;
