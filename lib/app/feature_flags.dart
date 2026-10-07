/// Build-time switches.
library;

/// Client demo mode: only Login, Home, Scan and the All Modules sheet work;
/// everything else on those screens is visible but inert, and every other
/// route is left out of the router (see README "Client demo mode").
// Set to false to restore the full app.
const bool kClientDemo = false;
