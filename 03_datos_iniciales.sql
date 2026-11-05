-- Eventos iniciales de AutoAudit

INSERT INTO public.eventos (nombre_evento)
VALUES ('INSERT'), ('UPDATE'), ('DELETE')
ON CONFLICT (nombre_evento) DO NOTHING;