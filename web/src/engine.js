import { LuaFactory } from 'wasmoon';
export const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));
export async function createEngine(
  saved,
  location = new URL('runtime/glue.wasm', document.baseURI).href
) {
  const lua = await new LuaFactory(location).createEngine({ enableProxy: false });
  const response = await fetch(new URL(__ENGINE_FILE__, document.baseURI));
  if (!response.ok) throw new Error(`Calculator engine could not load (${response.status}).`);
  await lua.doString(await response.text());
  const invoke = lua.global.get('webCall');
  const call = (name, payload = {}) => {
    const result = JSON.parse(invoke(name, payload));
    if (!result.ok) throw new Error(result.error || 'This action could not be completed.');
    return result.value;
  };
  const initial = JSON.parse(lua.global.get('webInit')(saved || {}));
  return { call, initial, close: () => lua.global.close() };
}
