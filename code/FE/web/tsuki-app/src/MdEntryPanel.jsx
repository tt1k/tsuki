function MdEntryPanel({
  title,
  sub,
  ctaLabel,
  isDragging = false,
  onPanelClick,
  onPanelKeyDown,
  onDragOver,
  onDragLeave,
  onDrop,
  onCtaClick,
  ariaLabel
}) {
  return (
    <div
      className={`md-entry-drop ${isDragging ? "is-dragging" : ""}`}
      role="button"
      tabIndex={0}
      aria-label={ariaLabel}
      onClick={onPanelClick}
      onKeyDown={onPanelKeyDown}
      onDragOver={onDragOver}
      onDragLeave={onDragLeave}
      onDrop={onDrop}
    >
      <span className="md-entry-title">{title}</span>
      <span className="md-entry-sub">{sub}</span>
      {ctaLabel ? (
        <button
          type="button"
          className="btn btn-primary md-entry-cta"
          onClick={(event) => {
            event.stopPropagation();
            onCtaClick?.();
          }}
        >
          {ctaLabel}
        </button>
      ) : null}
    </div>
  );
}

export default MdEntryPanel;
