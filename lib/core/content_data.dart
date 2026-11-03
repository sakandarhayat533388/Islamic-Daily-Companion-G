/// Bundled static content — daily duas and the tasbeeh dhikr catalogue.
/// Duas are short, well-known texts from Hisn al-Muslim / the Qur'an, kept
/// brief to stay accurate; Arabic is set in Amiri at render time.
class DuaEntry {
  final String arabic;
  final String translation;
  final String source;
  const DuaEntry(this.arabic, this.translation, this.source);
}

const List<DuaEntry> kDailyDuas = [
  DuaEntry('اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا',
      'O Allah, I ask You for beneficial knowledge, pure provision and accepted deeds.', 'Ibn Majah'),
  DuaEntry('اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
      'O Allah, help me to remember You, thank You and worship You excellently.', 'Abu Dawud'),
  DuaEntry('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      'Our Lord, give us good in this world and good in the Hereafter, and shield us from the punishment of the Fire.', 'Qur\'an 2:201'),
  DuaEntry('اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ عِلْمٍ لَا يَنْفَعُ، وَمِنْ قَلْبٍ لَا يَخْشَعُ، وَمِنْ نَفْسٍ لَا تَشْبَعُ، وَمِنْ دَعْوَةٍ لَا يُسْتَجَابُ لَهَا',
      'O Allah, I seek refuge in You from knowledge that brings no benefit, a heart that is not humble, a soul that is never satisfied, and a supplication that is not answered.', 'Muslim'),
  DuaEntry('يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ',
      'O Turner of hearts, keep my heart firm upon Your religion.', 'Tirmidhi'),
  DuaEntry('اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي',
      'O Allah, You are Pardoning and You love to pardon, so pardon me.', 'Tirmidhi'),
  DuaEntry('اللَّهُمَّ اغْفِرْ لِي ذَنْبِي كُلَّهُ، دِقَّهُ وَجِلَّهُ، وَأَوَّلَهُ وَآخِرَهُ، وَعَلَانِيَتَهُ وَسِرَّهُ',
      'O Allah, forgive me all my sins — the small and the great, the first and the last, the open and the secret.', 'Muslim'),
  DuaEntry('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
      'Glory be to Allah and His praise; glory be to Allah, the Magnificent.', 'Bukhari & Muslim'),
  DuaEntry('اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
      'O Allah, send prayers and peace upon our Prophet Muhammad.', 'Tirmidhi'),
  DuaEntry('حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
      'Allah is sufficient for us, and He is the best Disposer of affairs.', 'Qur\'an 3:173'),
  DuaEntry('اللَّهُمَّ لَا سَهْلَ إِلَّا مَا جَعَلْتَهُ سَهْلًا، وَأَنْتَ تَجْعَلُ الْحَزْنَ إِذَا شِئْتَ سَهْلًا',
      'O Allah, there is no ease except what You make easy, and You make the difficult easy if You wish.', 'Ibn Hibban'),
  DuaEntry('رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي',
      'My Lord, expand for me my chest and ease for me my task.', 'Qur\'an 20:25-26'),
  DuaEntry('اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ',
      'O Allah, I ask You for pardon and well-being in this world and the Hereafter.', 'Ibn Majah'),
  DuaEntry('رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً',
      'Our Lord, do not let our hearts deviate after You have guided us, and grant us mercy from Yourself.', 'Qur\'an 3:8'),
  DuaEntry('اللَّهُمَّ اهْدِنِي فِيمَنْ هَدَيْتَ، وَعَافِنِي فِيمَنْ عَافَيْتَ',
      'O Allah, guide me among those You have guided, and grant me well-being among those You have granted well-being.', 'Abu Dawud'),
  DuaEntry('لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
      'There is no god but You; glory be to You. Indeed, I have been of the wrongdoers.', 'Qur\'an 21:87'),
  DuaEntry('اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ',
      'O Allah, I seek refuge in You from anxiety and grief, incapacity and laziness, miserliness and cowardice.', 'Bukhari'),
  DuaEntry('رَبِّ زِدْنِي عِلْمًا', 'My Lord, increase me in knowledge.', 'Qur\'an 20:114'),
  DuaEntry('اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا وَقِنَا عَذَابَ النَّارِ',
      'O Allah, bless us in what You have provided us, and shield us from the punishment of the Fire.', 'Ibn Majah'),
  DuaEntry('أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيَّ الْقَيُّومَ وَأَتُوبُ إِلَيْهِ',
      'I seek forgiveness from Allah the Magnificent, besides Whom there is no god, the Ever-Living, the Sustainer, and I repent to Him.', 'Abu Dawud'),
  DuaEntry('اللَّهُمَّ اجْعَلْ فِي قَلْبِي نُورًا، وَفِي بَصَرِي نُورًا، وَفِي سَمْعِي نُورًا',
      'O Allah, place light in my heart, light in my sight, and light in my hearing.', 'Bukhari & Muslim'),
  DuaEntry('رَبَّنَا اغْفِرْ لَنَا وَلِإِخْوَانِنَا الَّذِينَ سَبَقُونَا بِالْإِيمَانِ',
      'Our Lord, forgive us and our brothers who preceded us in faith.', 'Qur\'an 59:10'),
  DuaEntry('اللَّهُمَّ أَصْلِحْ لِي دِينِي الَّذِي هُوَ عِصْمَةُ أَمْرِي، وَأَصْلِحْ لِي دُنْيَايَ الَّتِي فِيهَا مَعَاشِي',
      'O Allah, set right for me my religion, which is the safeguard of my affair, and set right for me my world in which I live.', 'Muslim'),
  DuaEntry('سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ',
      'Glory be to Allah, praise be to Allah, there is no god but Allah, and Allah is the Greatest.', 'Muslim'),
  DuaEntry('اللَّهُمَّ إِنِّي أَسْأَلُكَ رِضَاكَ وَالْجَنَّةَ، وَأَعُوذُ بِكَ مِنْ سَخَطِكَ وَالنَّارِ',
      'O Allah, I ask You for Your pleasure and Paradise, and I seek refuge in You from Your displeasure and the Fire.', 'Tirmidhi'),
  DuaEntry('رَبِّ هَبْ لِي مِنْ لَدُنْكَ ذُرِّيَّةً طَيِّبَةً إِنَّكَ سَمِيعُ الدُّعَاءِ',
      'My Lord, grant me from Yourself a good offspring. Indeed, You are the Hearer of supplication.', 'Qur\'an 3:38'),
  DuaEntry('اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ',
      'O Allah, shield me from Your punishment on the Day You resurrect Your servants.', 'Abu Dawud'),
  DuaEntry('يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ',
      'O Ever-Living, O Sustainer, by Your mercy I seek help.', 'Tirmidhi'),
  DuaEntry('اللَّهُمَّ لَكَ الْحَمْدُ كَمَا يَنْبَغِي لِجَلَالِ وَجْهِكَ وَعَظِيمِ سُلْطَانِكَ',
      'O Allah, to You belongs all praise, as befits the majesty of Your Face and the greatness of Your authority.', 'Ibn Majah'),
  DuaEntry('رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ أَنْتَ السَّمِيعُ الْعَلِيمُ',
      'Our Lord, accept this from us. Indeed, You are the Hearing, the Knowing.', 'Qur\'an 2:127'),
];

DuaEntry duaForDay(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year)).inDays;
  return kDailyDuas[dayOfYear % kDailyDuas.length];
}

/// Tasbeeh catalogue.
class DhikrEntry {
  final String id;
  final String arabic;
  final String transliteration;
  final String translation;
  final int defaultTarget;
  const DhikrEntry({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    this.defaultTarget = 33,
  });
}

const List<DhikrEntry> kBuiltinDhikr = [
  DhikrEntry(id: 'subhanallah', arabic: 'سُبْحَانَ اللَّهِ', transliteration: 'SubhanAllah', translation: 'Glory be to Allah', defaultTarget: 33),
  DhikrEntry(id: 'alhamdulillah', arabic: 'الْحَمْدُ لِلَّهِ', transliteration: 'Alhamdulillah', translation: 'All praise is for Allah', defaultTarget: 33),
  DhikrEntry(id: 'allahuakbar', arabic: 'اللَّهُ أَكْبَرُ', transliteration: 'Allahu Akbar', translation: 'Allah is the Greatest', defaultTarget: 34),
  DhikrEntry(id: 'lailaha', arabic: 'لَا إِلَهَ إِلَّا اللَّهُ', transliteration: 'La ilaha illallah', translation: 'There is no god but Allah', defaultTarget: 100),
  DhikrEntry(id: 'astaghfirullah', arabic: 'أَسْتَغْفِرُ اللَّهَ', transliteration: 'Astaghfirullah', translation: 'I seek Allah\'s forgiveness', defaultTarget: 100),
  DhikrEntry(id: 'salawat', arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', transliteration: 'Allahumma salli ala Muhammad', translation: 'O Allah, send blessings upon Muhammad', defaultTarget: 100),
  DhikrEntry(id: 'subhanallahiwabihamdihi', arabic: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', transliteration: 'SubhanAllahi wa bihamdihi', translation: 'Glory be to Allah and His praise', defaultTarget: 100),
  DhikrEntry(id: 'lahawla', arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ', transliteration: 'La hawla wa la quwwata illa billah', translation: 'There is no power except with Allah', defaultTarget: 100),
];

/// Post-prayer set: (dhikr id, target) in order — 33 / 33 / 34.
const List<(String, int)> kPostPrayerSet = [
  ('subhanallah', 33),
  ('alhamdulillah', 33),
  ('allahuakbar', 34),
];
