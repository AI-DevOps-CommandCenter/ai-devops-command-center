// Runs one n8n Code node script (after //#include inlining) outside n8n, with
// the n8n globals it uses ($input, $env, $, $execution, $workflow, $getWorkflowStaticData).
import { createRequire } from 'node:module';
import { buildCode } from '../scripts/build-workflows.mjs';

const require = createRequire(import.meta.url);

export async function runCodeNode(file, { items = [], env = {}, nodes = {}, staticData = {}, executionId = '1001', binary, workflow = { id: 'testwf', name: 'Test workflow', active: false } } = {}) {
  const code = buildCode(file);
  const wrap = (list) => ({ all: () => list, first: () => list[0], last: () => list[list.length - 1] });
  const $input = wrap(items.map((json, i) => (i === 0 && binary ? { json, binary } : { json })));
  const $ = (name) => {
    if (!(name in nodes)) throw new Error('Test did not provide node output for "' + name + '"');
    return wrap(nodes[name].map((json) => ({ json })));
  };
  const ctx = { helpers: { getBinaryDataBuffer: async () => { throw new Error('not available in tests'); } } };
  // URLSearchParams is shadowed because the n8n 2.x task-runner sandbox does not provide it.
  const fn = new Function('$input', '$env', '$', '$execution', '$workflow', '$getWorkflowStaticData', 'require', 'Buffer', 'URLSearchParams', `return (async function () {\n${code}\n}).call(this);`);
  const out = await fn.call(ctx, $input, env, $, { id: executionId }, workflow, () => staticData, require, Buffer, undefined);
  if (!Array.isArray(out)) throw new Error(file + ' did not return an array');
  return out.map((i) => i.json);
}
