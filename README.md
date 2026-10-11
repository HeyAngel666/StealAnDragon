# 🐉 Roube um Dragão (Roblox)

Jogo no estilo "Roube um Brainrot / Roube um Ovo": compre dragões na esteira, junte dinheiro, tranque sua base e roube os dragões dos outros jogadores.

**Arquivo para publicar:** `RoubeUmDragao.rbxlx`

---

## ✅ Como publicar (passo a passo)

1. Abra o **Roblox Studio** → **File > Open from File** → escolha `RoubeUmDragao.rbxlx`.
2. Clique em **Play** para testar. (O mapa é montado quando o jogo inicia; no modo de edição ele não aparece, é normal.)
3. **File > Publish to Roblox** → crie uma experiência nova (nome: *Roube um Dragão*).
4. **Game Settings > Security** → ligue **Enable Studio Access to API Services** (para salvar o progresso no Studio). → **Save**.
5. Pronto: o jogo já funciona. Os passos abaixo liberam os **Robux** e os **sons**.

### 💎 Ativar as compras com Robux
1. Entre em **create.roblox.com** → sua experiência → **Monetization**.
2. Crie os **Passes** e os **Developer Products** da tabela abaixo.
3. Copie o **ID** de cada um.
4. No Studio, abra **ReplicatedStorage > Shared > Monetization** e cole cada ID no lugar do `Id = 0`.
5. Publique de novo (**File > Publish to Roblox**).

> Enquanto o ID for `0`: no Studio a compra é simulada de graça (para testar). No jogo publicado aparece "Em breve".

**Gamepasses (compra única)**

| Nome | Preço sugerido | O que faz |
|---|---|---|
| VIP | 399 | +50% dinheiro, tag VIP, renda offline de 3h |
| Dinheiro x2 | 299 | Dragões rendem o dobro |
| Coleta Automática | 199 | Não precisa coletar |
| +4 Espaços | 249 | Mais 4 dragões na base |
| Velocidade Extra | 149 | Corre mais rápido |
| Sorte de Mutação | 349 | 30% de chance do dragão comprado subir de mutação |
| Tapa Buraco Negro | 199 | Tapa exclusivo, arremessa longe |
| Martelo do Banimento | 499 | Manda o alvo de volta pra base dele |

**Developer Products (compra repetida)**

| Nome | Preço sugerido | O que faz |
|---|---|---|
| Saco / Baú / Cofre de Dinheiro | 49 / 149 / 449 | Dinheiro na hora (cresce com o rebirth) |
| Dragão Lendário | 199 | Dragão Lendário aleatório |
| Dragão Mítico | 499 | Dragão Mítico aleatório |
| Escudo 10 min | 99 | Base trancada por 10 min |
| Sorte do Servidor | 149 | Sorte x3 por 15 min para todos |
| Chuva de Meteoros | 99 | Derruba todo mundo (menos você) |
| Congelar Todos | 129 | Congela os outros por 8s |
| Abrir Todas as Bases | 199 | Destranca todas as bases por 30s |

Os preços são sugestões. A loja do jogo busca o preço real direto do Roblox, então funciona com os **Preços Gerenciados** (preço regional) ligados.

### 🔊 Ativar os sons
1. Os áudios estão em `assets/audio/` (15 efeitos + música).
2. Em **create.roblox.com > Creations > Audio**, envie cada arquivo.
3. Copie o ID e cole em **ReplicatedStorage > Shared > Sounds** (no lugar do `Id = 0`, o nome do arquivo está ao lado).
4. Publique de novo.

### 🖼️ Ícone e thumbnail
- `assets/icon/icone.png` (512x512) e `assets/icon/thumbnail.png` (1920x1080).
- Envie em **Creator Hub > sua experiência > Places > Thumbnails / Icon**.

---

## 🎮 O que tem no jogo

- **Esteira de dragões**: 32 dragões em 8 raridades (Comum → Secreto), com nome, raridade, preço e renda.
- **Mutações**: Ouro (x1,5), Diamante (x2), Lava (x3, só em evento), Arco-Íris (x5).
- **8 bases** com até 20 espaços, botão de coletar por dragão e botão "Coletar tudo".
- **Trava da base** com laser (60s + 5s por rebirth). Base trancada por 30s ao entrar.
- **Roubo**: segure E no dragão de outra base, ele vai na sua cabeça (você fica mais lento) e precisa chegar na sua base. Tapa, armadilha, congelamento ou morte fazem o dragão voltar.
- **Equipamentos** (dinheiro do jogo): Tapa, Bobina de Velocidade, Armadilha, Tapa de Ferro, Bobina de Gravidade, Lança-Teia, Capa de Invisibilidade, Raio Congelante, Tapa Esmeralda.
- **10 Rebirths**: zera dinheiro/dragões, dá multiplicador, +1 espaço, trava mais longa e libera equipamentos.
- **Eventos automáticos** a cada ~9 min: Chuva de Ouro, Noite de Lava, Hora Lendária, Tempestade Arco-Íris, Frenesi do Dinheiro.
- **Para quem joga de graça**: dragão grátis ao começar, tutorial, presentes por tempo jogado (até um dragão Lendário em 60 min), prêmio diário, renda offline, códigos, bônus de amigos (+10% por amigo) e Índice (+5% por raridade completa).
- **Rankings globais** na praça: mais ricos e mais roubos.
- **Painel Admin** (só o dono vê): iniciar eventos, meteoros, congelar, abrir bases, soltar qualquer dragão, dar dragão a todos, avisos. Use para fazer "admin abuse" ao vivo.
- **Salvamento automático** com proteção contra perda de dados.

## 🎟️ Códigos
Edite em **ServerScriptService > Server > Services > RewardService** (tabela `Codes`). Atuais: `LANCAMENTO`, `DRAGAO`, `ROUBEUMDRAGAO`, `OBRIGADO`, `RELEASE`, `LAUNCH`, `STEALADRAGON`, `THANKYOU`.

## ⚙️ Ajustar o jogo
Quase tudo fica em **ReplicatedStorage > Shared**:
- `Config` – dinheiro inicial, tempos de trava, velocidades, presentes, eventos.
- `Dragons` – preço e renda de cada dragão.
- `Rebirths` – requisitos e multiplicadores.
- `Gear` – preço dos equipamentos.

Admins extras: coloque o UserId em `Config.AdminUserIds`.

## 💡 Dicas para faturar
- Faça um "admin abuse" fixo toda semana (mesmo dia e hora) e avise na descrição.
- Lance um código novo a cada atualização.
- Os itens de "Trollar" vendem bem em servidor cheio: todo mundo vê o aviso de quem comprou.

## 📝 Descrição sugerida para a página do jogo
> 🐉 ROUBE UM DRAGÃO! Compre dragões na esteira, junte dinheiro e roube os dragões raros das outras bases! Tranque sua base, use tapas, armadilhas e raios congelantes para proteger seu tesouro. 32 dragões, mutações de Ouro, Diamante, Lava e Arco-Íris, eventos a cada 9 minutos e Rebirths! 🎟️ Código: LANCAMENTO

---

## Para desenvolvedores
- Código-fonte em `src/` (projeto [Rojo](https://rojo.space)). Gerar o arquivo: `rojo build default.project.json -o RoubeUmDragao.rbxlx`.
- Regerar áudios: `python3 tools/gen_audio.py` (precisa de numpy e ffmpeg).
- Regerar ícone/thumbnail: `python3 tools/gen_icon.py` (precisa de Pillow).
