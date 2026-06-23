// Ambient module declarations for dependencies shipped without bundled types.
// React/react-dom are used (as `any`) only by the Proof Game's React rendering;
// declaring the modules removes the "implicitly has an 'any' type" diagnostics
// without pulling in @types packages that conflict with the pinned versions.
declare module 'react';
declare module 'react-dom/client';

// Cytoscape layout extensions ship without bundled type declarations.
declare module 'cytoscape-fcose';
declare module 'cytoscape-dagre';
declare module 'cytoscape-elk';
