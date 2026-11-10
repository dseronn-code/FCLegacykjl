// NUI de personagens: só coleta dados e mostra respostas do servidor (spc_core).
const $ = (id) => document.getElementById(id);
const ERRORS = {
  invalid_name_length: 'O nome deve ter entre 2 e 20 letras.',
  invalid_name_chars: 'Use apenas letras, espaço, hífen ou apóstrofo.',
  invalid_name: 'Use apenas letras, espaço, hífen ou apóstrofo.',
  blocked_name: 'Esse nome não é permitido na cidade.',
  invalid_birthdate: 'Data de nascimento inválida.',
  invalid_age: 'O personagem deve ter entre 18 e 90 anos.',
  no_slots: 'Você não tem vagas livres para novos personagens.',
  rate_limited: 'Aguarde alguns segundos e tente novamente.',
};
const errorText = (code) => ERRORS[code] || 'Não foi possível concluir. Tente novamente.';
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'spc_multichar';

let state = { characters: [], slots: 2 };

async function post(name, body) {
  const res = await fetch(`https://${resource}/${name}`, { method: 'POST', body: JSON.stringify(body ?? {}) });
  return res.json();
}

function formatDate(iso) {
  const [y, m, d] = (iso || '').split('-');
  return d ? `${d}/${m}/${y}` : '';
}

function renderList() {
  const list = $('list');
  list.replaceChildren();
  for (const c of state.characters) {
    const b = document.createElement('button');
    b.className = 'card';
    b.type = 'button';
    const info = document.createElement('span');
    info.textContent = `${c.firstName} ${c.lastName}`;
    const small = document.createElement('small');
    small.textContent = `${c.citizenid} · ${formatDate(c.birthdate)}`;
    info.append(small);
    const go = document.createElement('span');
    go.textContent = 'Entrar →';
    b.append(info, go);
    b.addEventListener('click', () => select(c.citizenid, b));
    list.append(b);
  }
  for (let i = state.characters.length; i < state.slots; i++) {
    const b = document.createElement('button');
    b.className = 'card empty';
    b.type = 'button';
    b.textContent = '+ Criar personagem';
    b.addEventListener('click', showForm);
    list.append(b);
  }
  list.hidden = false;
  $('form').hidden = true;
  list.querySelector('button')?.focus();
}

function showForm() {
  $('list').hidden = true;
  $('form').hidden = false;
  $('error').textContent = '';
  $('form').firstName.focus();
}

async function select(citizenid, button) {
  button.disabled = true;
  const r = await post('select', { citizenid });
  if (!r.ok) { button.disabled = false; $('listError').textContent = errorText(r.error); }
}

$('cancel').addEventListener('click', renderList);

$('form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const f = e.target;
  const data = {
    firstName: f.firstName.value.trim(), lastName: f.lastName.value.trim(), birthdate: f.birthdate.value,
    gender: f.gender.value, nationality: f.nationality.value,
  };
  if (!data.firstName || !data.lastName || !data.birthdate) { $('error').textContent = 'Preencha todos os campos.'; return; }
  $('submit').disabled = true;
  const r = await post('create', data);
  $('submit').disabled = false;
  if (!r.ok) { $('error').textContent = errorText(r.error); return; }
  f.reset();
  if (r.characters) state.characters = r.characters;
  renderList();
});

window.addEventListener('message', ({ data }) => {
  if (data.t === 'open') {
    state = { characters: data.characters || [], slots: data.slots || 2 };
    const sel = $('form').nationality;
    sel.replaceChildren(...(data.nationalities || ['Brasileira']).map((n) => new Option(n, n)));
    $('app').hidden = false;
    renderList();
  } else if (data.t === 'close') {
    $('app').hidden = true;
  }
});
