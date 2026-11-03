local data = {
  channels = {
    { id = 101, name = "101 Globo 4K", logo = "ch101.png" },
    { id = 102, name = "102 SBT HD", logo = "ch102.png" },
    { id = 103, name = "103 Record TV", logo = "ch103.png" },
    { id = 104, name = "104 Band Sports", logo = "ch104.png" },
    { id = 105, name = "105 TV Cultura", logo = "ch105.png" },
    { id = 106, name = "106 TV Brasil 3.0", logo = "ch106.png" },
    { id = 107, name = "107 RedeTV! 4K", logo = "ch107.png" },
    { id = 108, name = "108 Canal Gov HD", logo = "ch108.png" }
  },
  timeline = {
    { time = "20:00", minutes = 1200 },
    { time = "20:30", minutes = 1230 },
    { time = "21:00", minutes = 1260 },
    { time = "21:30", minutes = 1290 },
    { time = "22:00", minutes = 1320 },
    { time = "22:30", minutes = 1350 },
    { time = "23:00", minutes = 1380 },
    { time = "23:30", minutes = 1410 }
  },
  schedule = {
    {
      { title = "Jornal Nacional", span = 1, durationMin = 30 },
      { title = "Novela das 9 (4K HDR)", span = 1, durationMin = 30 },
      { title = "Copa Libertadores Ao Vivo", span = 1, durationMin = 30 },
      { title = "Pos-Jogo Libertadores", span = 1, durationMin = 30 },
      { title = "Tela Quente UHD", span = 1, durationMin = 30 },
      { title = "Jornal da Globo", span = 1, durationMin = 30 },
      { title = "Conversa com Bial", span = 1, durationMin = 30 },
      { title = "Corujao 4K", span = 1, durationMin = 30 }
    },
    {
      { title = "SBT Brasil", span = 1, durationMin = 30 },
      { title = "Programa do Ratinho", span = 1, durationMin = 30 },
      { title = "Cine Espetacular", span = 1, durationMin = 30 },
      { title = "A Praca e Nossa", span = 1, durationMin = 30 },
      { title = "The Noite", span = 1, durationMin = 30 },
      { title = "SBT News", span = 1, durationMin = 30 },
      { title = "Operacao Mesquita", span = 1, durationMin = 30 },
      { title = "SBT PodNight", span = 1, durationMin = 30 }
    },
    {
      { title = "Jornal da Record", span = 1, durationMin = 30 },
      { title = "Serie Reis", span = 1, durationMin = 30 },
      { title = "A Fazenda Ao Vivo", span = 1, durationMin = 30 },
      { title = "Cine Record Especial", span = 1, durationMin = 30 },
      { title = "Camera Record", span = 1, durationMin = 30 },
      { title = "JR 24h Madrugada", span = 1, durationMin = 30 },
      { title = "Chicago Fire", span = 1, durationMin = 30 },
      { title = "Fala Que Eu Te Escuto", span = 1, durationMin = 30 }
    },
    {
      { title = "Jornal da Band", span = 1, durationMin = 30 },
      { title = "Formula 1 Qualifying", span = 1, durationMin = 30 },
      { title = "MasterChef Brasil", span = 1, durationMin = 30 },
      { title = "Apito Final", span = 1, durationMin = 30 },
      { title = "Band Esporte Clube", span = 1, durationMin = 30 },
      { title = "Jornal da Noite", span = 1, durationMin = 30 },
      { title = "Esporte Total", span = 1, durationMin = 30 },
      { title = "Cinema na Madrugada", span = 1, durationMin = 30 }
    },
    {
      { title = "Jornal da Cultura", span = 1, durationMin = 30 },
      { title = "Roda Viva Especial", span = 1, durationMin = 30 },
      { title = "Metropolis", span = 1, durationMin = 30 },
      { title = "Provoca", span = 1, durationMin = 30 },
      { title = "Persona em Foco", span = 1, durationMin = 30 },
      { title = "Cultura Documentarios", span = 1, durationMin = 30 },
      { title = "Ensaio Musical", span = 1, durationMin = 30 },
      { title = "Mosaico Brasil", span = 1, durationMin = 30 }
    },
    {
      { title = "Reporter Brasil", span = 1, durationMin = 30 },
      { title = "Cinema Nacional", span = 1, durationMin = 30 },
      { title = "Sem Censura", span = 1, durationMin = 30 },
      { title = "Brasil Visto de Cima", span = 1, durationMin = 30 },
      { title = "Trilha de Letras", span = 1, durationMin = 30 },
      { title = "Cena Instrumental", span = 1, durationMin = 30 },
      { title = "Documentario TV 3.0", span = 1, durationMin = 30 },
      { title = "Retrospectiva Brasil", span = 1, durationMin = 30 }
    },
    {
      { title = "RedeTV! News", span = 1, durationMin = 30 },
      { title = "SuperPop Ao Vivo", span = 1, durationMin = 30 },
      { title = "Bastidores do Carnaval", span = 1, durationMin = 30 },
      { title = "Leitura Dinamica", span = 1, durationMin = 30 },
      { title = "Sensacional", span = 1, durationMin = 30 },
      { title = "Mega Senha", span = 1, durationMin = 30 },
      { title = "Operacao de Risco", span = 1, durationMin = 30 },
      { title = "Esporte Interativo", span = 1, durationMin = 30 }
    },
    {
      { title = "Voz do Brasil", span = 1, durationMin = 30 },
      { title = "Brasil em Dia", span = 1, durationMin = 30 },
      { title = "Gov Noticias", span = 1, durationMin = 30 },
      { title = "Painel TV 3.0", span = 1, durationMin = 30 },
      { title = "Ciencia & Tecnologia", span = 1, durationMin = 30 },
      { title = "Cultura Popular", span = 1, durationMin = 30 },
      { title = "Especial Amazonia", span = 1, durationMin = 30 },
      { title = "Horizonte Digital", span = 1, durationMin = 30 }
    }
  }
}
return data

