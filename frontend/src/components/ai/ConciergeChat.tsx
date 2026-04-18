import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { sendChatMessage, type ChatHistoryEntry } from '../../lib/apiClient';

interface Message {
  role: 'user' | 'assistant';
  content: string;
}

export default function ConciergeChat(): JSX.Element {
  const { t } = useTranslation();
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Auto-scroll to the newest message
  useEffect(() => {
    if (open) {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages, open]);

  // Focus input when chat opens
  useEffect(() => {
    if (open) {
      inputRef.current?.focus();
    }
  }, [open]);

  // Close on Escape
  useEffect(() => {
    if (!open) return;
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('keydown', handleKey);
    return () => document.removeEventListener('keydown', handleKey);
  }, [open]);

  const handleSend = async () => {
    const trimmed = input.trim();
    if (!trimmed || loading) return;

    const userMessage: Message = { role: 'user', content: trimmed };
    const updatedMessages = [...messages, userMessage];
    setMessages(updatedMessages);
    setInput('');
    setError(null);
    setLoading(true);

    const history: ChatHistoryEntry[] = updatedMessages.slice(0, -1).map((m) => ({
      role: m.role,
      content: m.content,
    }));

    try {
      const response = await sendChatMessage(trimmed, history);
      setMessages((prev) => [...prev, { role: 'assistant', content: response.reply }]);
    } catch {
      setError(t('ai.chat.errorSend'));
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="concierge-chat">
      {/* Floating toggle button */}
      <button
        type="button"
        className="concierge-chat__toggle"
        onClick={() => setOpen((prev) => !prev)}
        aria-label={open ? t('ai.chat.closeLabel') : t('ai.chat.openLabel')}
        aria-expanded={open}
        aria-controls="concierge-chat-panel"
      >
        {open ? '✕' : '💬'}
      </button>

      {/* Chat panel */}
      {open && (
        <div
          id="concierge-chat-panel"
          className="concierge-chat__panel"
          role="region"
          aria-label={t('ai.chat.panelLabel')}
        >
          <div className="concierge-chat__header">
            <div>
              <p className="concierge-chat__title">{t('ai.chat.title')}</p>
              <p className="concierge-chat__subtitle">{t('ai.chat.subtitle')}</p>
            </div>
            <button
              type="button"
              className="concierge-chat__close"
              onClick={() => setOpen(false)}
              aria-label={t('ai.chat.closeLabel')}
            >
              ✕
            </button>
          </div>

          <div
            className="concierge-chat__messages"
            role="log"
            aria-live="polite"
            aria-label={t('ai.chat.messagesLabel')}
          >
            {messages.length === 0 && (
              <p className="concierge-chat__empty">{t('ai.chat.emptyHint')}</p>
            )}
            {messages.map((msg, i) => (
              <div
                key={i}
                className={`concierge-chat__bubble concierge-chat__bubble--${msg.role}`}
              >
                {msg.content}
              </div>
            ))}
            {loading && (
              <div role="status" aria-label={t('ai.chat.typingLabel')}>
                <div className="concierge-chat__bubble concierge-chat__bubble--assistant concierge-chat__typing">
                  <span />
                  <span />
                  <span />
                </div>
              </div>
            )}
            {error && (
              <div className="concierge-chat__bubble concierge-chat__bubble--error" role="alert">
                {error}
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          <div className="concierge-chat__input-row">
            <input
              ref={inputRef}
              type="text"
              className="concierge-chat__input"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={t('ai.chat.inputPlaceholder')}
              aria-label={t('ai.chat.inputLabel')}
              disabled={loading}
              maxLength={500}
            />
            <button
              type="button"
              className="concierge-chat__send"
              onClick={handleSend}
              disabled={loading || !input.trim()}
              aria-label={t('ai.chat.sendLabel')}
            >
              ➤
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
