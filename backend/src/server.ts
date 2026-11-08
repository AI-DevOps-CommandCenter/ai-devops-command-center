// Must stay the first import: loads .env before any config is read.
import "./config/load-env.js";

import { createApp } from "./app.js";
import { loadServerConfig } from "./config/env.js";

const config = loadServerConfig();
const app = createApp(config);

app.listen(config.port, () => {
  console.log(`Server running at http://localhost:${config.port}`);
});
