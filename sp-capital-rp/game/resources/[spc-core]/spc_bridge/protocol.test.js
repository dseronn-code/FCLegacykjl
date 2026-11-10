// node protocol.test.js  (não use node --test com o caminho: '[spc-core]' é interpretado como glob)
const test = require('node:test');
const assert = require('node:assert');
const { sign, verify, ReplayCache } = require('./protocol');

const SECRET = 's3gr3d0';
const now = 1731240000000;
const envelope = (cmd, secret = SECRET) => { const body = JSON.stringify(cmd); return JSON.stringify({ body, sig: sign(secret, body) }); };
const cmd = (o = {}) => ({ id: 'c1', type: 'player.kick', actor: 'staff:1', ts: now, payload: { citizenid: 'SPC12345' }, ...o });

test('aceita comando assinado válido', () => {
  const r = verify(envelope(cmd()), SECRET, now, new ReplayCache());
  assert.equal(r.ok, true); assert.equal(r.cmd.type, 'player.kick'); assert.equal(r.cmd.payload.citizenid, 'SPC12345');
});
test('recusa assinatura de outro segredo', () => {
  assert.equal(verify(envelope(cmd(), 'outro'), SECRET, now, new ReplayCache()).error, 'invalid_signature');
});
test('recusa corpo adulterado', () => {
  const env = JSON.parse(envelope(cmd()));
  env.body = env.body.replace('SPC12345', 'SPC99999');
  assert.equal(verify(JSON.stringify(env), SECRET, now, new ReplayCache()).error, 'invalid_signature');
});
test('recusa sem segredo configurado', () => {
  assert.equal(verify(envelope(cmd()), '', now, new ReplayCache()).error, 'no_secret');
});
test('recusa replay do mesmo id', () => {
  const rc = new ReplayCache();
  assert.equal(verify(envelope(cmd()), SECRET, now, rc).ok, true);
  assert.equal(verify(envelope(cmd()), SECRET, now + 1, rc).error, 'replay');
});
test('recusa comando expirado e tipo inválido', () => {
  assert.equal(verify(envelope(cmd({ ts: now - 31000 })), SECRET, now, new ReplayCache()).error, 'expired');
  assert.equal(verify(envelope(cmd({ type: 'Player.Kick' })), SECRET, now, new ReplayCache()).error, 'invalid_type');
});
test('recusa JSON inválido e sig malformada', () => {
  assert.equal(verify('{', SECRET, now, new ReplayCache()).error, 'invalid_json');
  assert.equal(verify(JSON.stringify({ body: '{}', sig: 'zz' }), SECRET, now, new ReplayCache()).error, 'invalid_signature');
});
