import { submarinerVariants } from './submariner-variants.mjs';

export const iconModels = [
  { id: 'rolex-submariner', title: 'Rolex Submariner', reference: '124060', hourCycle: 12,
    url: 'https://www.rolex.com/watches/submariner/m124060-0001',
    dial: [275, 412, 474, 474], center: [512, 649], shape: 'circle', style: 'mercedes' },
  ...submarinerVariants,
  { id: 'omega-speedmaster', title: 'Omega Speedmaster Moonwatch', reference: '310.30.42.50.01.001', hourCycle: 12,
    url: 'https://www.omegawatches.com.hk/en-hk/watch-omega-speedmaster-moonwatch-professional-co-axial-master-chronometer-chronograph-42-mm-31030425001001',
    dial: [207, 401, 610, 610], center: [512, 706], secondsCenter: [371, 706.5],
    chronographMinuteCenter: [651.5, 706.5], chronographHourCenter: [511.5, 841.5],
    shape: 'circle', style: 'speedmaster',
    mechanicalControls: [
      {action: 'chronograph-toggle', bounds: [868, 474, 94, 114]},
      {action: 'chronograph-reset', bounds: [865, 845, 96, 121]},
    ] },
  { id: 'cartier-tank', title: 'Cartier Tank Must', reference: 'WSTA0041', hourCycle: 12,
    url: 'https://int.cartier.com/de-eu/kollektionen/watches/herrenuhren/tank/tank-must/wsta0041-tank-must-de-cartier.html',
    dial: [398, 516, 228, 284], center: [512, 658], shape: 'rectangle', style: 'sword',
    holes: [1108, 1157, 1207, 1255, 1305, 1355, 1404] },
  { id: 'ap-royal-oak', title: 'Audemars Piguet Royal Oak', reference: '15510ST.OO.1320ST.06', hourCycle: 12,
    url: 'https://www.audemarspiguet.com/en/watch-collection/royal-oak/15510ST.OO.1320ST.06',
    dial: [201, 353, 622, 622], center: [512, 664], shape: 'circle', style: 'baton', date: [733, 644, 51, 45] },
  { id: 'casio-gshock', title: 'Casio G-Shock DW-5600', reference: 'DW-5600E / DW-5600UE', hourCycle: 24,
    url: 'https://www.casio.com/us/watches/gshock/product.DW-5600E-1V/',
    dial: [314, 540, 400, 342], center: [512, 711], shape: 'rectangle', digital: true,
    mechanicalControls: [
      {action: 'gshock-a', bounds: [215, 580, 62, 86]},
      {action: 'gshock-b', bounds: [764, 580, 54, 86], longAction: 'gshock-flash'},
      {action: 'gshock-c', bounds: [215, 786, 62, 86]},
      {action: 'gshock-d', bounds: [764, 786, 54, 86]},
    ],
    holes: [1258, 1306, 1357, 1408, 1459] },
  { id: 'hamilton-pulsar', title: 'Hamilton Pulsar P1 · 1972', reference: 'P1', hourCycle: 12,
    url: 'https://americanwatchmuseum.org/catalog/pulsar-p1-time-computer/',
    dial: [295, 563, 435, 280], center: [512, 704], shape: 'rectangle', digital: true,
    interactionProfile: 'pulsar',
    mechanicalControls: [{action: 'pulsar-light', bounds: [448, 1015, 132, 71], longAction: 'pulsar-seconds'}] }
];
