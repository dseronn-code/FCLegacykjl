// HUD: aplica mensagens pequenas { t, v } vindas do client.lua. Sem loops próprios.
const $ = (s) => document.querySelector(s);
const setBar = (sel, v) => $(sel + ' i').style.setProperty('--v', Math.max(0, Math.min(100, Number(v) || 0)));
const DIRS = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];

const handlers = {
  visible: (v) => { $('#hud').hidden = !v; },
  health: (v) => setBar('.health', v),
  armor: (v) => setBar('.armor', v),
  status: (v) => {
    // status do servidor vai de 0 a 100; ausente = cheio (fome/sede) ou zero (estresse)
    setBar('.hunger', v.hunger ?? 100); setBar('.thirst', v.thirst ?? 100); setBar('.stress', v.stress ?? 0);
  },
  talking: (v) => $('#voice').classList.toggle('talking', !!v),
  voice: (v) => document.querySelectorAll('#voice b').forEach((b, i) => b.classList.toggle('on', i < v)),
  radio: (v) => { $('#radio').hidden = !v; $('#radio').textContent = v ? `📻 ${v} MHz` : ''; },
  street: (v) => { $('#street').textContent = v; },
  heading: (v) => { $('#dir').textContent = DIRS[Math.round(v / 45) % 8]; },
  vehicle: (v) => { $('#vehicle').hidden = !v; $('#hud').classList.toggle('in-vehicle', !!v); },
  speed: (v) => { $('#speed').textContent = v; },
  fuel: (v) => setBar('.fuel', v),
};

window.addEventListener('message', ({ data }) => handlers[data?.t]?.(data.v));
