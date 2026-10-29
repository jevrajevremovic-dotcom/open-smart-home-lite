/// Short bedtime stories written for this app, in each language, as
/// paragraphs (read aloud one at a time).
typedef BedtimeStory = ({String title, List<String> paragraphs});

const _sr = <BedtimeStory>[
  (
    title: 'Oblačić koji nije hteo da pada',
    paragraphs: [
      'Iznad jednog malog grada živeo je oblačić po imenu Pahuljko. Bio je mekan kao jastuk i beo kao mleko, i najviše od svega voleo je da gleda krovove ispod sebe.',
      'Jednog dana veliki oblaci rekoše: „Vreme je, Pahuljko. Treba da padneš kao kiša i napojiš cveće.” Ali Pahuljko se uplašio. „Šta ako se izgubim? Šta ako više ne budem oblak?”',
      'Tada mu stari vetar tiho šapnu: „Kad padneš, bićeš kap na latici ruže. Onda ćeš biti potok, pa reka, pa more. A jednog toplog jutra sunce će te podići, i ponovo ćeš biti oblak.”',
      'Pahuljko se nasmeši, duboko udahnu i polako, polako pade na usnulu baštu. Te noći cveće je sanjalo slatke snove, a negde visoko, novi oblačić je već čekao jutro.',
      'Laku noć, mali oblačiću. Laku noć i tebi.',
    ],
  ),
  (
    title: 'Meda koji je brojao zvezde',
    paragraphs: [
      'U šumi iza brda živeo je mali meda Brundo. Svake večeri, kad mama ugasi svetlo u pećini, Brundo bi provirio napolje i počeo da broji zvezde.',
      'Jedan, dva, tri… Ali zvezda je bilo toliko mnogo da bi se uvek zbunio negde oko dvadeset i počeo ispočetka. „Nikad ih neću sve izbrojati”, uzdahnuo je jedne noći.',
      'Sova sa grane mu reče: „Ne moraš ih sve izbrojati, Brundo. Dovoljno je da izabereš jednu i kažeš joj laku noć. Ona će čuvati tvoj san.”',
      'Brundo izabra najmanju, onu što je treperila iznad starog hrasta. „Laku noć, zvezdice”, šapnu on, sklupča se pored mame i zaspa pre nego što je stigao do dva.',
      'A zvezdica je treptala celu noć, baš za njega.',
    ],
  ),
  (
    title: 'Svetionik i mali brod',
    paragraphs: [
      'Na kraju jednog stenovitog rta stajao je stari svetionik. Svake noći palio je svoju veliku lampu i polako je okretao, da brodovi na moru znaju gde je obala.',
      'Jedne maglovite noći, mali ribarski brod se izgubio među talasima. Mornar je bio umoran, a more je bilo tamno i hladno.',
      'Ali kroz maglu se pojavi zrak svetla — jednom, pa još jednom, pa još jednom, mirno i strpljivo, kao otkucaji srca. Brodić se okrenu prema svetlu i polako zaplovi kući.',
      'Kad je stigao u luku, mornar pogleda svetionik i reče: „Hvala ti, stari prijatelju.” A svetionik je nastavio da se okreće, tiho, sve do jutra.',
      'I tvoja kuća ima svoje svetlo. Spavaj mirno, ovde si sigurno.',
    ],
  ),
  (
    title: 'Lisica koja je čuvala tišinu',
    paragraphs: [
      'Kad padne mrak, u šumi se sve utiša. Ptice spuste glave pod krila, zečevi se zavuku u jazbine, a lišće prestane da šušti.',
      'Mala lisica Riđa imala je važan posao: da obiđe šumu i proveri da li svi spavaju. Hodala je na prstima, tiho, tiše od mesečine.',
      'Kod potoka je našla budnu žabicu. „Ne mogu da zaspim”, reče žabica. Riđa sede pored nje i zajedno su slušale kako voda peva svoju sporu, sanjivu pesmu.',
      'Posle malo vremena žabica je hrkala, a Riđa se nasmešila i krenula kući, u svoju toplu jazbinu ispod korena. Šuma je spavala, a i ona je zatvorila oči.',
      'Psst… sada je i tvoje vreme za san.',
    ],
  ),
];

const _en = <BedtimeStory>[
  (
    title: 'The little cloud who did not want to fall',
    paragraphs: [
      'Above a small town lived a little cloud called Puff. He was as soft as a pillow and as white as milk, and more than anything he loved to watch the rooftops below.',
      'One day the big clouds said, "It is time, Puff. You must fall as rain and give the flowers a drink." But Puff was afraid. "What if I get lost? What if I am never a cloud again?"',
      'Then the old wind whispered, "When you fall, you will be a drop on a rose petal. Then a stream, then a river, then the sea. And one warm morning the sun will lift you up, and you will be a cloud once more."',
      'Puff smiled, took a deep breath, and slowly, slowly fell onto the sleeping garden. That night the flowers dreamed sweet dreams, and somewhere high above, a new little cloud was already waiting for the morning.',
      'Good night, little cloud. Good night to you too.',
    ],
  ),
  (
    title: 'The bear who counted stars',
    paragraphs: [
      'In the forest behind the hill lived a little bear called Bruno. Every evening, when Mum put out the light in the cave, Bruno peeked outside and began to count the stars.',
      'One, two, three… But there were so many that he always got muddled somewhere around twenty and had to start again. "I will never count them all," he sighed one night.',
      'The owl on the branch said, "You do not have to count them all, Bruno. Just choose one and say good night to it. It will watch over your sleep."',
      'Bruno chose the smallest, the one twinkling above the old oak. "Good night, little star," he whispered, curled up next to Mum, and was asleep before he reached two.',
      'And the little star twinkled all night long, just for him.',
    ],
  ),
  (
    title: 'The lighthouse and the little boat',
    paragraphs: [
      'At the end of a rocky cape stood an old lighthouse. Every night it lit its great lamp and turned it slowly, so that ships at sea would know where the shore was.',
      'One misty night, a small fishing boat got lost among the waves. The sailor was tired, and the sea was dark and cold.',
      'But through the mist came a beam of light — once, and again, and again, calm and patient, like a heartbeat. The little boat turned towards the light and slowly sailed home.',
      'When it reached the harbour, the sailor looked up at the lighthouse and said, "Thank you, old friend." And the lighthouse kept on turning, quietly, until morning.',
      'Your home has its light too. Sleep well, you are safe here.',
    ],
  ),
  (
    title: 'The fox who kept the quiet',
    paragraphs: [
      'When darkness falls, the forest grows quiet. Birds tuck their heads under their wings, rabbits creep into their burrows, and the leaves stop rustling.',
      'Little Rusty the fox had an important job: to walk round the forest and make sure everyone was asleep. She tiptoed softly, softer than moonlight.',
      'By the stream she found a little frog who was wide awake. "I cannot sleep," said the frog. Rusty sat down beside her, and together they listened to the water singing its slow, sleepy song.',
      'After a while the frog was snoring, and Rusty smiled and went home to her warm den under the roots. The forest was asleep, and she closed her eyes too.',
      'Shh… now it is your turn to sleep.',
    ],
  ),
];

/// Stories in [languageCode] (Serbian or English).
List<BedtimeStory> bedtimeStories(String languageCode) =>
    languageCode == 'sr' ? _sr : _en;
