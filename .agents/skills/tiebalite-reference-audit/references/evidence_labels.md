# Evidence labels

- `CODE_EVIDENCE`: local path, symbol, and call chain support the claim.
- `RUNTIME_EVIDENCE`: deterministic screenshot, recording, response summary, or fixture supports it.
- `INFERENCE`: multiple facts support a conclusion, but no direct source; state the inference chain.
- `UNKNOWN`: insufficient evidence. Never silently promote to fact.

Every endpoint claim should include method/path family, encoder, request/response type, auth, pagination, error fields and source symbols. Every product behavior should include entry, state transition, visible result and return-state behavior.
