import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/locale_notifier.dart';

abstract class AppLocalizations {
  // ── General ──────────────────────────────────────────────────────────────
  String get settings;
  String get cancel;
  String get delete;
  String get close;
  String get language;
  String get hungarian;
  String get english;
  String get tripLog;
  String get permissionsRequired;

  // ── Home page ─────────────────────────────────────────────────────────────
  String get connectionType;
  String get brand;
  String get model;
  String get searchDevices;
  String get stopSearch;
  String get demoMode;
  String get connectingInProgress;
  String get stopConnection;
  String get searching;
  String get noDevicesFound;
  String autoConnecting(String name);
  String get autoConnectFailed;
  String get enableBluetooth;
  String bleScanError(String error);
  String connectingAttempt(int attempt, int max);
  String bleConnectingAttempt(int attempt, int max);
  String get classicConnectFailed;
  String get bleConnectFailed;

  // ── OBD data page ─────────────────────────────────────────────────────────
  String get initializing;
  String get noActiveConnection;
  String get adapterReset;
  String resetAttempt(int n);
  String get configuring;
  String get ecuTest;
  String get ecuNotResponding;
  String get liveConnection;
  String get noDataIgnition;
  String get connectionLost;
  String get charging;
  String get connected;
  String get viewSwitch;
  String get dashboardPickerTitle;
  String get listView;
  String get rangeDebugTitle;
  String get exit;
  String get lowSoc;
  String get highBatteryTemp;
  String get cellImbalance;
  // Dashboard names
  String get dashDriving;
  String get dashBattery;
  String get dashChargingMonitor;
  String get dashChart;
  String get dashCustomCharts;
  String get dashSensors;
  String get dashInstrumentPanel;
  String get dashPhevPlugin;
  String get dashPhevIce;

  // ── ICE alerts ───────────────────────────────────────────────────────────────
  String get thresholdLabel;
  String get highCoolantTemp;
  String get lowFuelLevel;

  // ── Settings — ICE alert section ─────────────────────────────────────────────
  String get evPhevSectionLabel;
  String get iceSectionLabel;
  String get coolantTempMaxLabel;
  String get coolantTempMaxDesc;
  String get fuelLevelMinLabel;
  String get fuelLevelMinDesc;

  // ── PHEV kombinált műszerfal (phev_dashboard.dart) ───────────────────────────
  String get evPower;
  String get evPowerShort;
  String get coolantIce;
  String get battTempShort;
  String get hvVoltage;
  String get evModeShort;
  String get engineActiveShort;
  String get electricShort;
  String get engineOnCard;
  String get evModeCard;
  String get engineOffMultiline;
  String get evChargeBarLabel;
  String get electricRangeBarLabel;
  String get fuelIceBarLabel;
  String get reverseLabel;
  String get speedGaugeLabel;

  // ── PHEV ICE nézet (phev_ice_view.dart) ──────────────────────────────────────
  String get iceEngineActiveLabel;
  String get electricModeEngineOff;
  String get rpmGaugeLabel;
  String get fuelLabel;
  String get coolantTempLabel;
  String get engineLoadLabel;
  String get fuelEmptyLabel;
  String get fuelFullLabel;
  String get iceDataSourceLabel;

  // ── Trips page ────────────────────────────────────────────────────────────
  String get deleteAll;
  String get confirmDeleteAll;
  String get confirmDeleteTrip;
  String get noTripsYet;
  String get tripsAutoRecorded;
  String get interrupted;
  String get tripCountLabel;
  String get totalLabel;
  String get consumptionLabel;

  // ── Settings page ─────────────────────────────────────────────────────────
  String get resetToDefault;
  String get appearance;
  String get consumptionRange;
  String get units;
  String get alertThresholds;
  String get autoConnect;
  String get developer;
  String get appTheme;
  String get automatic;
  String get light;
  String get dark;
  String get speedAndDistance;
  String get temperature;
  String get socMinimum;
  String get socMinDescription;
  String get batteryTempMax;
  String get batteryTempMaxDescription;
  String get cellBalanceMax;
  String get cellBalanceMaxDescription;
  String get autoConnectTitle;
  String get autoConnectDescription;
  String get noSavedDevice;
  String get resetSettingsTitle;
  String get confirmResetSettings;
  String get settingsReset;
  String get debugLog;
  String get debugLogDescription;
  String get rangeEstimationMode;
  String get rangeAutomatic;
  String get rangeTemperature;
  String get rangeManual;
  String get fixedConsumptionNorm;
  String get expectedConsumptionChange;
  String consumptionHint(double v);

  // ── Log nézet ─────────────────────────────────────────────────────────────
  String get loading;
  String get clearLogTooltip;
  String get logCopiedSnackbar;
  String get copyToClipboardTooltip;

  // ── Általános megosztott mezőfeliratok ───────────────────────────────────
  String get disconnect;
  String get powerLabel;
  String get speedLabel;
  String get voltageLabel;
  String get currentLabel;
  String get aux12VLabel;
  String get batteryMaxTempLabel;
  String get batteryMinTempLabel;
  String get operatingHoursLabel;
  String get socDisplayLabel;
  String get socBmsLabel;
  String get sohLabel;
  String get remainingEnergyLabel;
  String get drivingParamsLabel;
  String get statisticsLabel;
  String get maxChargePowerLabel;
  String get maxDischargePowerLabel;
  String get rangeEstimateLabel;
  String get chartConsumptionLabel;
  String get minCellVoltLabel;
  String get maxCellVoltLabel;
  String get avgCellVoltLabel;
  String get cellSpreadLabel;

  // ── Töltési monitor ───────────────────────────────────────────────────────
  String get chargingInProgress;
  String get elapsedPrefix;
  String get chargingPowerLabel;
  String get energyAddedLabel;
  String get timeToFullLabel;
  String get chargingSpeedLabel;
  String get chargingDetailsLabel;
  String get energyNeededToFullLabel;
  String get socBarTitle;
  String highBattTempWarning(double t);
  String elevatedTempWarning(double t);

  // ── EV grafikon ───────────────────────────────────────────────────────────
  String get dataCollectionInProgress;

  // ── EV műszerfal ──────────────────────────────────────────────────────────
  String get chargeBarTitle;
  String get rangeBarTitle;
  String get cellsTitle;
  String get minCellLabel;
  String get maxCellLabel;
  String get avgCellLabel;
  String get cellDiffLabel;
  String get lifeStatsTitle;
  String get chargedKwhLabel;
  String get dischargedKwhLabel;
  String get batteryDetailsLabel;
  String tempBasedRange(int t);

  // ── ICE műszerfal ─────────────────────────────────────────────────────────
  String get coolantLabel;
  String get intakeAirLabel;
  String get throttleLabel;
  String get aux12VShort;
  String get boostPressureLabel;
  String get airMassFlowLabel;
  String get obcLabel;
  String get avgConsumptionLabel;
  String get instantConsumptionLabel;
  String get distanceTravelledLabel;
  String get rangeLabel;
  String get noDtcLabel;

  // ── Egyéni grafikonok ─────────────────────────────────────────────────────
  String get addChartTitle;
  String get noChartSelected;
  String get addChartHint;
  String get chartDataCollecting;

  // ── Menetek oldal ─────────────────────────────────────────────────────────
  String gpsPointsRecorded(int n);
  String get tapForMap;
  String get routeLegend;
  String get tripStartLabel;
  String get tripEndLabel;
  String get tripConsumptionPrefix;
  String get maxLabel;
  String get avgLabel;

  // ── Cella feszültség rács ─────────────────────────────────────────────────
  String get cellDataCollectionInProgress;
  String get fromAvgLabel;

  // ── KITT műszerfal ────────────────────────────────────────────────────────
  String get kittCoolantBar;
  String get kittFuelBar;
  String get kittEngineLoadBar;
  String get kittIntakeBar;
  String get kittThrottleCard;
  String get kittAux12VCard;
  String get kittIntakeCard;

  // ── EV szenzornézet — szekciócímek ───────────────────────────────────────
  String get sectionDriving;
  String get sectionSoc;
  String get sectionVoltCurr;
  String get sectionCells;
  String get sectionTemps;
  String get sectionBattHealth;
  String get sectionGasEngine;

  // ── EV szenzornézet — sorfeliratok ───────────────────────────────────────
  String get rangeEstShort;
  String get maxRangeLabel;
  String get hvCurrLabel;
  String get cellMinAvgMaxDelta;
  String get coolantInLabel;
  String get coolantOutLabel;
  String get totalChargedLabel;
  String get totalDischargedLabel;
  String get engineRpmSensLabel;
  String get fuelLevelSensLabel;
  String get coolantTempShortLabel;
  String moduleTempLabel(int n);

  // ── Cella feszültség stat sor ─────────────────────────────────────────────
  String get avgShortLabel;

  // ── Töltési görbe widget ──────────────────────────────────────────────────
  String get chargeChartTitle;
  String get chargeDataCollecting;

  // ── Beállítások — hatótáv-becslés módleírások ─────────────────────────────
  String get autoModeDescription;
  String get tempModeDescription;

  // ── Dashboard panel (fekvő tájolás) ──────────────────────────────────────
  String get dashFuelLabel;
  String get dashTempLabel;
  String get dashBattLabel;
  String get dashVoltageLabel;
  String get dashExtTempLabel;

  // ── Főoldal ────────────────────────────────────────────────────────────────
  String get unknownDevice;

  // ── Hatótáv debug pánel ───────────────────────────────────────────────────
  String get dbgNominalCapacity;
  String get dbgActualCapacity;
  String get dbgLifetimeWhKm;
  String get dbgExternalTemp;
  String get dbgWhSource;
  String get dbgFinalWh;
  String get dbgMaxRange;
  String get dbgUnknown;
  String get dbgNotEnoughData;
  String get dbgOdometerUnreadable;
  String get dbgDefault;
  String dbgTripsLabel(int n);

  // ── OBD Monitor ───────────────────────────────────────────────────────────
  String get obdMonitorTitle;
  String obdMonitorSubtitle(int n);
  String get obdMonFilterHint;
  String get obdMonOnlyErrorsTip;
  String get obdMonCopyTip;
  String get obdMonDeleteTip;
  String get obdMonCopiedSnack;
  String obdMonEntries(int n);
  String obdMonShown(int n);
  String get obdMonOk;
  String get obdMonErr;
  String get obdMonNoTraffic;
  String get obdMonNoMatch;
  String get obdMonNoResponse;

  // ── Engedélyek és kapcsolat (UI) ──────────────────────────────────────────
  String get permissionsPermanentlyDenied;
  String get openAppSettings;
  String get bluetoothOffWarning;
  String get reconnect;
  String get reconnecting;
  String get backOnceMore;
  String get protocolLabel;
  String makeModelsLabel(String make);

  factory AppLocalizations.of(String languageCode) {
    if (languageCode == 'en') return _EnStrings();
    return _HuStrings();
  }
}

// ── Context extension (use only in build() for reactive rebuilds) ──────────

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => read<LocaleNotifier>().strings;
}

// ═════════════════════════════════════════════════════════════════════════════
// Hungarian
// ═════════════════════════════════════════════════════════════════════════════

class _HuStrings implements AppLocalizations {
  @override String get settings           => 'Beállítások';
  @override String get cancel             => 'Mégsem';
  @override String get delete             => 'Törlés';
  @override String get close              => 'Bezárás';
  @override String get language           => 'Nyelv';
  @override String get hungarian          => 'Magyar';
  @override String get english            => 'English';
  @override String get tripLog            => 'Menetnapló';
  @override String get permissionsRequired =>
      'Bluetooth és helymeghatározási engedélyek szükségesek.';

  @override String get connectionType     => 'Kapcsolat típusa';
  @override String get brand              => 'Márka';
  @override String get model              => 'Modell';
  @override String get searchDevices      => 'Eszközök keresése';
  @override String get stopSearch         => 'Keresés leállítása';
  @override String get demoMode           => 'Bemutató mód (eszköz nélkül)';
  @override String get connectingInProgress => 'Kapcsolódás folyamatban...';
  @override String get stopConnection     => 'Csatlakozás leállítása';
  @override String get searching          => 'Keresés folyamatban...';
  @override String get noDevicesFound     => 'Nem találhatók eszközök.';
  @override String autoConnecting(String name) => 'Auto-connect: $name...';
  @override String get autoConnectFailed  =>
      'Auto-connect sikertelen. Kattints az eszközre a kézi csatlakozáshoz.';
  @override String get enableBluetooth    =>
      'Kérjük, kapcsold be a Bluetooth-t a telefon beállításaiban.';
  @override String bleScanError(String e) => 'BLE scan hiba: $e';
  @override String connectingAttempt(int a, int m) => 'Csatlakozás... ($a/$m)';
  @override String bleConnectingAttempt(int a, int m) => 'BLE csatlakozás... ($a/$m)';
  @override String get classicConnectFailed =>
      'Nem sikerült csatlakozni.\n'
      'Ellenőrizd, hogy az eszköz párosítva van-e az Android Bluetooth beállításokban.';
  @override String get bleConnectFailed   =>
      'BLE csatlakozás sikertelen.\n'
      'Ellenőrizd, hogy az adapter BLE módot támogat-e.';

  @override String get initializing       => 'Inicializálás...';
  @override String get noActiveConnection => 'Nincs aktív kapcsolat';
  @override String get adapterReset       => 'Adapter reset...';
  @override String resetAttempt(int n)    => 'Reset... ($n/3)';
  @override String get configuring        => 'Beállítás...';
  @override String get ecuTest            => 'ECU teszt...';
  @override String get ecuNotResponding   => 'ECU nem válaszol';
  @override String get liveConnection     => 'Élő kapcsolat';
  @override String get noDataIgnition     => 'Nincs adat – gyújtás?';
  @override String get connectionLost     => 'Kapcsolat elveszett';
  @override String get charging           => 'Töltés';
  @override String get connected          => 'Csatlakoztatva';
  @override String get viewSwitch         => 'Nézet váltás';
  @override String get dashboardPickerTitle => 'Műszerfal kiválasztása';
  @override String get listView           => 'Lista nézet';
  @override String get rangeDebugTitle    => 'Hatótáv becslés — Debug';
  @override String get exit               => 'Kilépés';
  @override String get lowSoc             => 'Alacsony töltöttség';
  @override String get highBatteryTemp    => 'Magas akkumulátor hőmérséklet';
  @override String get cellImbalance      => 'Cellaegyensúly probléma';
  @override String get dashDriving        => 'Vezetés';
  @override String get dashBattery        => 'Akkumulátor';
  @override String get dashChargingMonitor => 'Töltési monitor';
  @override String get dashChart          => 'Grafikon';
  @override String get dashCustomCharts   => 'Egyéni grafikonok';
  @override String get dashSensors        => 'Összes szenzor';
  @override String get dashInstrumentPanel => 'Műszerfal';
  @override String get dashPhevPlugin     => 'Plugin kombináló';
  @override String get dashPhevIce        => 'Benzinmotor';

  @override String get thresholdLabel     => 'Küszöb';
  @override String get highCoolantTemp    => 'Magas hűtővíz hőmérséklet';
  @override String get lowFuelLevel       => 'Alacsony üzemanyag szint';

  @override String get evPhevSectionLabel => 'EV / PHEV';
  @override String get iceSectionLabel    => 'Belső égésű motor (ICE)';
  @override String get coolantTempMaxLabel => 'Hűtővíz max. hőmérséklet';
  @override String get coolantTempMaxDesc =>
      'Riasztás, ha a motor hűtővíz hőmérséklete meghaladja ezt az értéket.';
  @override String get fuelLevelMinLabel  => 'Üzemanyag min. szint';
  @override String get fuelLevelMinDesc   =>
      'Riasztás, ha az üzemanyag szintje ez alá süllyed.';

  @override String get evPower            => 'EV Teljesítmény';
  @override String get evPowerShort       => 'EV Telj.';
  @override String get coolantIce         => 'Hűtő (ICE)';
  @override String get battTempShort      => 'Akku hőm.';
  @override String get hvVoltage          => 'HV feszültség';
  @override String get evModeShort        => 'EV mód';
  @override String get engineActiveShort  => 'MOTOR AKTÍV';
  @override String get electricShort      => 'ELEKTROMOS';
  @override String get engineOnCard       => 'MOTOR BE';
  @override String get evModeCard         => 'EV MÓD';
  @override String get engineOffMultiline => 'Motor\náll';
  @override String get evChargeBarLabel   => 'EV TÖLTÖTTSÉG';
  @override String get electricRangeBarLabel => 'ELEKTROMOS HATÓTÁV';
  @override String get fuelIceBarLabel    => 'ÜZEMANYAG (ICE)';
  @override String get reverseLabel       => 'TOLATÁS';
  @override String get speedGaugeLabel    => 'SEBESSÉG';

  @override String get iceEngineActiveLabel   => 'BENZINMOTOR AKTÍV';
  @override String get electricModeEngineOff  => 'ELEKTROMOS MÓD — MOTOR ÁLL';
  @override String get rpmGaugeLabel          => 'FORDULATSZÁM';
  @override String get fuelLabel              => 'Üzemanyag';
  @override String get coolantTempLabel       => 'Hűtőfolyadék hőmérséklet';
  @override String get engineLoadLabel        => 'Motor terhelés';
  @override String get fuelEmptyLabel         => 'E (üres)';
  @override String get fuelFullLabel          => 'F (teli)';
  @override String get iceDataSourceLabel     => 'Benzinmotor adatok — PCM (7E0)';

  @override String get deleteAll          => 'Összes törlése';
  @override String get confirmDeleteAll   =>
      'Biztosan törlöd az összes rögzített menetet?';
  @override String get confirmDeleteTrip  => 'Törli ezt a menetet?';
  @override String get noTripsYet         => 'Nincs még rögzített menet.';
  @override String get tripsAutoRecorded  =>
      'A menetek OBD kapcsolódás után automatikusan\nkerülnek rögzítésre.';
  @override String get interrupted        => 'MEGSZAKADT';
  @override String get tripCountLabel     => 'menet';
  @override String get totalLabel         => 'összesen';
  @override String get consumptionLabel   => 'fogyasztás';

  @override String get resetToDefault     => 'Visszaállítás alapértelmezettre';
  @override String get appearance         => 'Megjelenés';
  @override String get consumptionRange   => 'Fogyasztás / hatótáv-becslés';
  @override String get units              => 'Mértékegységek';
  @override String get alertThresholds    => 'Riasztási küszöbök';
  @override String get autoConnect        => 'Automatikus csatlakozás';
  @override String get developer          => 'Fejlesztő';
  @override String get appTheme           => 'Alkalmazás témája';
  @override String get automatic          => 'Automatikus';
  @override String get light              => 'Világos';
  @override String get dark               => 'Sötét';
  @override String get speedAndDistance   => 'Sebesség és távolság';
  @override String get temperature        => 'Hőmérséklet';
  @override String get socMinimum         => 'SOC minimum';
  @override String get socMinDescription  =>
      'Ha a töltöttség erre az értékre esik, riasztás.';
  @override String get batteryTempMax     => 'Akku hőmérséklet maximum';
  @override String get batteryTempMaxDescription =>
      'Ennél magasabb akkumulátor-hőfoknál riasztás.';
  @override String get cellBalanceMax     => 'Cellaegyensúly maximum';
  @override String get cellBalanceMaxDescription =>
      'Ennél nagyobb max-min cellaeltérésnél riasztás.';
  @override String get autoConnectTitle   => 'Automatikus csatlakozás';
  @override String get autoConnectDescription =>
      'Kocsi indításakor az alkalmazás automatikusan '
      'csatlakozik az utoljára használt OBD eszközhöz.';
  @override String get noSavedDevice      =>
      'Még nincs elmentett eszköz. '
      'Első csatlakozás után automatikusan megjegyzi.';
  @override String get resetSettingsTitle => 'Visszaállítás';
  @override String get confirmResetSettings =>
      'Biztosan visszaállítod az összes beállítást az alapértékre?';
  @override String get settingsReset      => 'Beállítások visszaállítva.';
  @override String get debugLog           => 'Debug napló';
  @override String get debugLogDescription =>
      'OBD kommunikáció és hibaesemények részletes naplója.';
  @override String get rangeEstimationMode => 'Hatótáv-becslés módja';
  @override String get rangeAutomatic     => 'Automatikus';
  @override String get rangeTemperature   => 'Hőmérséklet';
  @override String get rangeManual        => 'Manuális';
  @override String get fixedConsumptionNorm => 'Rögzített fogyasztás-norma';
  @override String get expectedConsumptionChange => 'Várható fogyasztás-módosítás:';
  @override String consumptionHint(double v) {
    if (v < 100) return 'Rendkívül hatékony (pl. könnyű városi EV)';
    if (v < 140) return 'Hatékony (pl. Ioniq, Model 3)';
    if (v < 180) return 'Átlagos EV fogyasztás';
    if (v < 250) return 'Nagyobb SUV / téli körülmény';
    return 'Nagy fogyasztás (pl. Audi e-tron, Rivian)';
  }

  @override String get loading               => 'Betöltés...';
  @override String get clearLogTooltip       => 'Napló törlése';
  @override String get logCopiedSnackbar     => 'Napló vágólapra másolva';
  @override String get copyToClipboardTooltip => 'Másolás vágólapra';

  @override String get disconnect            => 'Lecsatlakozás';
  @override String get powerLabel            => 'Teljesítmény';
  @override String get speedLabel            => 'Sebesség';
  @override String get voltageLabel          => 'Feszültség';
  @override String get currentLabel          => 'Áram';
  @override String get aux12VLabel           => '12V akku';
  @override String get batteryMaxTempLabel   => 'Akku max hőm.';
  @override String get batteryMinTempLabel   => 'Akku min hőm.';
  @override String get operatingHoursLabel   => 'Üzemóra';
  @override String get socDisplayLabel       => 'Töltöttség (kijelző)';
  @override String get socBmsLabel           => 'Töltöttség (BMS)';
  @override String get sohLabel              => 'Állapot (SOH)';
  @override String get remainingEnergyLabel  => 'Maradék energia';
  @override String get drivingParamsLabel    => 'Menetparaméterek';
  @override String get statisticsLabel       => 'Statisztika';
  @override String get maxChargePowerLabel   => 'Max töltési telj.';
  @override String get maxDischargePowerLabel => 'Max kisütési telj.';
  @override String get rangeEstimateLabel    => 'Becsült hatótáv';
  @override String get chartConsumptionLabel => 'Fogyasztás';
  @override String get minCellVoltLabel      => 'Min cellafeszültség';
  @override String get maxCellVoltLabel      => 'Max cellafeszültség';
  @override String get avgCellVoltLabel      => 'Átlag cellafeszültség';
  @override String get cellSpreadLabel       => 'Cellaegyensúly (szórás)';

  @override String get chargingInProgress    => 'Töltés folyamatban';
  @override String get elapsedPrefix         => 'Eltelt';
  @override String get chargingPowerLabel    => 'Töltési teljesítmény';
  @override String get energyAddedLabel      => 'Hozzáadott energia';
  @override String get timeToFullLabel       => 'Idő 100%-ig';
  @override String get chargingSpeedLabel    => 'Töltési sebesség';
  @override String get chargingDetailsLabel  => 'Töltési részletek';
  @override String get energyNeededToFullLabel => '100%-ig szükséges';
  @override String get socBarTitle           => 'Töltöttség (SOC)';
  @override String highBattTempWarning(double t) =>
      'Magas akkumulátor hőmérséklet: ${t.toStringAsFixed(0)}°C';
  @override String elevatedTempWarning(double t) =>
      'Megemelkedett hőmérséklet: ${t.toStringAsFixed(0)}°C';

  @override String get dataCollectionInProgress => 'Adatgyűjtés folyamatban...';

  @override String get chargeBarTitle        => 'TÖLTÖTTSÉG';
  @override String get rangeBarTitle         => 'HATÓTÁV (becslés)';
  @override String get cellsTitle            => 'CELLÁK';
  @override String get minCellLabel          => 'Min cella';
  @override String get maxCellLabel          => 'Max cella';
  @override String get avgCellLabel          => 'Átlag cella';
  @override String get cellDiffLabel         => 'Különbség (Δ)';
  @override String get lifeStatsTitle        => 'ÉLETTARTAM STATISZTIKA';
  @override String get chargedKwhLabel       => 'Töltve';
  @override String get dischargedKwhLabel    => 'Merítve';
  @override String get batteryDetailsLabel   => 'Akkumulátor részletek';
  @override String tempBasedRange(int t)     => '${t}°C alapján';

  @override String get coolantLabel          => 'Hűtőfolyadék';
  @override String get intakeAirLabel        => 'Szívólevegő';
  @override String get throttleLabel         => 'Gázpedál';
  @override String get aux12VShort           => 'Akku (12V)';
  @override String get boostPressureLabel    => 'Töltőnyomás';
  @override String get airMassFlowLabel      => 'Levegő tömegáram (MAF)';
  @override String get obcLabel              => 'FEDÉLZETI COMPUTER';
  @override String get avgConsumptionLabel   => 'Átlagfogy.';
  @override String get instantConsumptionLabel => 'Pillanatfogy.';
  @override String get distanceTravelledLabel => 'Megtett táv';
  @override String get rangeLabel            => 'Hatótávolság';
  @override String get noDtcLabel            => 'Nincs aktív hibakód (DTC)';

  @override String get addChartTitle         => 'Grafikon hozzáadása';
  @override String get noChartSelected       => 'Még nincs kiválasztott grafikon';
  @override String get addChartHint          =>
      'Nyomd meg a + gombot egy grafikon\nhozzáadásához';
  @override String get chartDataCollecting   => 'Adatok gyűjtése...';

  @override String gpsPointsRecorded(int n)  => '$n GPS pont rögzítve';
  @override String get tapForMap             => 'koppints a térképért';
  @override String get routeLegend           => 'Útvonal';
  @override String get tripStartLabel        => 'Start';
  @override String get tripEndLabel          => 'Cél';
  @override String get tripConsumptionPrefix => 'Fogyasztás:';
  @override String get maxLabel              => 'Max:';
  @override String get avgLabel              => 'Átlag:';

  @override String get cellDataCollectionInProgress => 'Cella adatok gyűjtése...';
  @override String get fromAvgLabel          => 'az átlagtól';

  @override String get kittCoolantBar        => 'HŰTŐFOLYADÉK °C';
  @override String get kittFuelBar           => 'ÜZEMANYAG %';
  @override String get kittEngineLoadBar     => 'MOTOR TERH. %';
  @override String get kittIntakeBar         => 'SZÍVÓCSŐ HŐM °C';
  @override String get kittThrottleCard      => 'GÁZPEDÁL';
  @override String get kittAux12VCard        => '12V AKKU';
  @override String get kittIntakeCard        => 'SZÍVÓCSŐ';

  @override String get sectionDriving        => 'MENET';
  @override String get sectionSoc            => 'TÖLTÖTTSÉG';
  @override String get sectionVoltCurr       => 'FESZÜLTSÉG & ÁRAM';
  @override String get sectionCells          => 'CELLÁK';
  @override String get sectionTemps          => 'HŐMÉRSÉKLETEK';
  @override String get sectionBattHealth     => 'AKKUMULÁTOR EGÉSZSÉG';
  @override String get sectionGasEngine      => 'BENZINMOTOR';

  @override String get rangeEstShort         => 'Hatótáv (becslés)';
  @override String get maxRangeLabel         => 'Max hatótáv';
  @override String get hvCurrLabel           => 'HV áram';
  @override String get cellMinAvgMaxDelta    => 'Min / Átl / Max / Δ';
  @override String get coolantInLabel        => 'Hűtő be';
  @override String get coolantOutLabel       => 'Hűtő ki';
  @override String get totalChargedLabel     => 'Összesen töltve';
  @override String get totalDischargedLabel  => 'Összesen merítve';
  @override String get engineRpmSensLabel    => 'Fordulatszám';
  @override String get fuelLevelSensLabel    => 'Üzemanyagszint';
  @override String get coolantTempShortLabel => 'Hűtőfolyadék hőm.';
  @override String moduleTempLabel(int n)    => 'Modul $n';

  @override String get avgShortLabel         => 'Átl';

  @override String get chargeChartTitle      => 'Töltési görbe';
  @override String get chargeDataCollecting  => 'Töltési adatok gyűjtése...';

  @override String get autoModeDescription   =>
      'Menet közben méri a tényleges fogyasztást '
      '(sebesség × teljesítmény integrálás), és azt '
      'használja a hatótáv számításához.\n'
      'Amíg nincs elegendő adat (< 500 m), '
      'az alapértelmezett 140 Wh/km értéket alkalmazza.';
  @override String get tempModeDescription   =>
      'IP-alapú helymeghatározással lekéri a kültéri hőmérsékletet '
      '(Open-Meteo API, 15 perces gyorsítótár), és azzal '
      'korrigálja a hatótáv-becslést.\n'
      'Hideg időben a fogyasztás nő, melegben csökken.';

  @override String get dashFuelLabel         => 'ÜZEMANYAG';
  @override String get dashTempLabel         => 'HŐMÉRSÉKLET';
  @override String get dashBattLabel         => 'AKKU';
  @override String get dashVoltageLabel      => 'FESZÜLTSÉG';
  @override String get dashExtTempLabel      => 'KÜL. HŐMÉR.';

  @override String get unknownDevice         => 'Ismeretlen eszköz';

  @override String get dbgNominalCapacity    => 'Névleges kapacitás';
  @override String get dbgActualCapacity     => 'Valós kapacitás';
  @override String get dbgLifetimeWhKm       => 'Élettartam Wh/km';
  @override String get dbgExternalTemp       => 'Kültéri hőmérséklet';
  @override String get dbgWhSource           => 'Wh/km forrás';
  @override String get dbgFinalWh            => 'Végső Wh/km';
  @override String get dbgMaxRange           => 'Max hatótáv (100%)';
  @override String get dbgUnknown            => 'ismeretlen';
  @override String get dbgNotEnoughData      => 'nincs elég adat';
  @override String get dbgOdometerUnreadable => 'kilométeróra nem olvasható';
  @override String get dbgDefault            => 'alapértelmezett';
  @override String dbgTripsLabel(int n)      => '$n menet';

  // ── OBD Monitor ───────────────────────────────────────────────────────────
  @override String get obdMonitorTitle       => 'OBD Monitor';
  @override String obdMonitorSubtitle(int n) => 'Nyers forgalom • $n bejegyzés';
  @override String get obdMonFilterHint      => 'Szűrő: 2248, 7E4, 62...';
  @override String get obdMonOnlyErrorsTip   => 'Csak hibák / üres válaszok';
  @override String get obdMonCopyTip         => 'Napló másolása vágólapra';
  @override String get obdMonDeleteTip       => 'Napló törlése';
  @override String get obdMonCopiedSnack     => 'Napló másolva a vágólapra';
  @override String obdMonEntries(int n)      => '$n bejegyzés';
  @override String obdMonShown(int n)        => '↳ $n látható';
  @override String get obdMonOk              => 'OK';
  @override String get obdMonErr             => 'HIBA';
  @override String get obdMonNoTraffic       =>
      'Még nincs OBD forgalom.\nIndíts pollozást az adatok megjelenítéséhez.';
  @override String get obdMonNoMatch         => 'Nincs a szűrőnek megfelelő bejegyzés.';
  @override String get obdMonNoResponse      => '(nincs válasz)';

  // ── Engedélyek és kapcsolat (UI) ──────────────────────────────────────────
  @override String get permissionsPermanentlyDenied =>
      'A Bluetooth és helymeghatározási engedélyeket véglegesen letiltottad.\n'
      'A használathoz a rendszerbeállításokban kell engedélyezned őket.';
  @override String get openAppSettings       => 'Beállítások megnyitása';
  @override String get bluetoothOffWarning   =>
      'A Bluetooth ki van kapcsolva. Kapcsold be az eszközök kereséséhez.';
  @override String get reconnect             => 'Újrakapcsolódás';
  @override String get reconnecting          => 'Újrakapcsolódás...';
  @override String get backOnceMore          => 'Nyomd meg még egyszer a kilépéshez';
  @override String get protocolLabel         => 'Protokoll';
  @override String makeModelsLabel(String make) => '$make modellek';
}

// ═════════════════════════════════════════════════════════════════════════════
// English
// ═════════════════════════════════════════════════════════════════════════════

class _EnStrings implements AppLocalizations {
  @override String get settings           => 'Settings';
  @override String get cancel             => 'Cancel';
  @override String get delete             => 'Delete';
  @override String get close              => 'Close';
  @override String get language           => 'Language';
  @override String get hungarian          => 'Magyar';
  @override String get english            => 'English';
  @override String get tripLog            => 'Trip log';
  @override String get permissionsRequired =>
      'Bluetooth and location permissions are required.';

  @override String get connectionType     => 'Connection type';
  @override String get brand              => 'Brand';
  @override String get model              => 'Model';
  @override String get searchDevices      => 'Search devices';
  @override String get stopSearch         => 'Stop search';
  @override String get demoMode           => 'Demo mode (no device)';
  @override String get connectingInProgress => 'Connecting...';
  @override String get stopConnection     => 'Stop connection';
  @override String get searching          => 'Searching...';
  @override String get noDevicesFound     => 'No devices found.';
  @override String autoConnecting(String name) => 'Auto-connect: $name...';
  @override String get autoConnectFailed  =>
      'Auto-connect failed. Tap a device for manual connection.';
  @override String get enableBluetooth    =>
      'Please enable Bluetooth in your phone settings.';
  @override String bleScanError(String e) => 'BLE scan error: $e';
  @override String connectingAttempt(int a, int m) => 'Connecting... ($a/$m)';
  @override String bleConnectingAttempt(int a, int m) => 'BLE connecting... ($a/$m)';
  @override String get classicConnectFailed =>
      'Connection failed.\n'
      'Check that the device is paired in Android Bluetooth settings.';
  @override String get bleConnectFailed   =>
      'BLE connection failed.\n'
      'Check that the adapter supports BLE mode.';

  @override String get initializing       => 'Initializing...';
  @override String get noActiveConnection => 'No active connection';
  @override String get adapterReset       => 'Adapter reset...';
  @override String resetAttempt(int n)    => 'Reset... ($n/3)';
  @override String get configuring        => 'Configuring...';
  @override String get ecuTest            => 'ECU test...';
  @override String get ecuNotResponding   => 'ECU not responding';
  @override String get liveConnection     => 'Live connection';
  @override String get noDataIgnition     => 'No data – ignition?';
  @override String get connectionLost     => 'Connection lost';
  @override String get charging           => 'Charging';
  @override String get connected          => 'Connected';
  @override String get viewSwitch         => 'Switch view';
  @override String get dashboardPickerTitle => 'Select dashboard';
  @override String get listView           => 'List view';
  @override String get rangeDebugTitle    => 'Range estimate — Debug';
  @override String get exit               => 'Exit';
  @override String get lowSoc             => 'Low battery level';
  @override String get highBatteryTemp    => 'High battery temperature';
  @override String get cellImbalance      => 'Cell imbalance';
  @override String get dashDriving        => 'Driving';
  @override String get dashBattery        => 'Battery';
  @override String get dashChargingMonitor => 'Charging monitor';
  @override String get dashChart          => 'Chart';
  @override String get dashCustomCharts   => 'Custom charts';
  @override String get dashSensors        => 'All sensors';
  @override String get dashInstrumentPanel => 'Dashboard';
  @override String get dashPhevPlugin     => 'Plugin combined';
  @override String get dashPhevIce        => 'ICE engine';

  @override String get thresholdLabel     => 'Threshold';
  @override String get highCoolantTemp    => 'High coolant temperature';
  @override String get lowFuelLevel       => 'Low fuel level';

  @override String get evPhevSectionLabel => 'EV / PHEV';
  @override String get iceSectionLabel    => 'Internal combustion engine (ICE)';
  @override String get coolantTempMaxLabel => 'Coolant max. temperature';
  @override String get coolantTempMaxDesc =>
      'Alert when engine coolant temperature exceeds this value.';
  @override String get fuelLevelMinLabel  => 'Fuel minimum level';
  @override String get fuelLevelMinDesc   =>
      'Alert when fuel level drops below this value.';

  @override String get evPower            => 'EV Power';
  @override String get evPowerShort       => 'EV Pwr.';
  @override String get coolantIce         => 'Coolant (ICE)';
  @override String get battTempShort      => 'Batt. temp.';
  @override String get hvVoltage          => 'HV voltage';
  @override String get evModeShort        => 'EV mode';
  @override String get engineActiveShort  => 'ENGINE ON';
  @override String get electricShort      => 'ELECTRIC';
  @override String get engineOnCard       => 'ENGINE ON';
  @override String get evModeCard         => 'EV MODE';
  @override String get engineOffMultiline => 'Engine\noff';
  @override String get evChargeBarLabel   => 'EV CHARGE';
  @override String get electricRangeBarLabel => 'ELECTRIC RANGE';
  @override String get fuelIceBarLabel    => 'FUEL (ICE)';
  @override String get reverseLabel       => 'REVERSE';
  @override String get speedGaugeLabel    => 'SPEED';

  @override String get iceEngineActiveLabel   => 'ICE ENGINE ACTIVE';
  @override String get electricModeEngineOff  => 'ELECTRIC MODE — ENGINE OFF';
  @override String get rpmGaugeLabel          => 'RPM';
  @override String get fuelLabel              => 'Fuel';
  @override String get coolantTempLabel       => 'Coolant temperature';
  @override String get engineLoadLabel        => 'Engine load';
  @override String get fuelEmptyLabel         => 'E (empty)';
  @override String get fuelFullLabel          => 'F (full)';
  @override String get iceDataSourceLabel     => 'ICE engine data — PCM (7E0)';

  @override String get deleteAll          => 'Delete all';
  @override String get confirmDeleteAll   =>
      'Are you sure you want to delete all recorded trips?';
  @override String get confirmDeleteTrip  => 'Delete this trip?';
  @override String get noTripsYet         => 'No trips recorded yet.';
  @override String get tripsAutoRecorded  =>
      'Trips are automatically recorded\nafter OBD connection.';
  @override String get interrupted        => 'INTERRUPTED';
  @override String get tripCountLabel     => 'trips';
  @override String get totalLabel         => 'total';
  @override String get consumptionLabel   => 'consumption';

  @override String get resetToDefault     => 'Reset to defaults';
  @override String get appearance         => 'Appearance';
  @override String get consumptionRange   => 'Consumption / range estimate';
  @override String get units              => 'Units';
  @override String get alertThresholds    => 'Alert thresholds';
  @override String get autoConnect        => 'Auto-connect';
  @override String get developer          => 'Developer';
  @override String get appTheme           => 'App theme';
  @override String get automatic          => 'Automatic';
  @override String get light              => 'Light';
  @override String get dark               => 'Dark';
  @override String get speedAndDistance   => 'Speed and distance';
  @override String get temperature        => 'Temperature';
  @override String get socMinimum         => 'SOC minimum';
  @override String get socMinDescription  =>
      'Alert when battery level drops to this value.';
  @override String get batteryTempMax     => 'Battery temp maximum';
  @override String get batteryTempMaxDescription =>
      'Alert when battery temperature exceeds this value.';
  @override String get cellBalanceMax     => 'Cell balance maximum';
  @override String get cellBalanceMaxDescription =>
      'Alert when max–min cell voltage spread exceeds this.';
  @override String get autoConnectTitle   => 'Auto-connect';
  @override String get autoConnectDescription =>
      'On car start, the app automatically connects '
      'to the last used OBD device.';
  @override String get noSavedDevice      =>
      'No saved device yet. '
      'Will remember automatically after the first connection.';
  @override String get resetSettingsTitle => 'Reset';
  @override String get confirmResetSettings =>
      'Are you sure you want to reset all settings to defaults?';
  @override String get settingsReset      => 'Settings reset.';
  @override String get debugLog           => 'Debug log';
  @override String get debugLogDescription =>
      'Detailed OBD communication and error event log.';
  @override String get rangeEstimationMode => 'Range estimation mode';
  @override String get rangeAutomatic     => 'Automatic';
  @override String get rangeTemperature   => 'Temperature';
  @override String get rangeManual        => 'Manual';
  @override String get fixedConsumptionNorm => 'Fixed consumption rate';
  @override String get expectedConsumptionChange => 'Expected consumption adjustment:';
  @override String consumptionHint(double v) {
    if (v < 100) return 'Very efficient (e.g. lightweight city EV)';
    if (v < 140) return 'Efficient (e.g. Ioniq, Model 3)';
    if (v < 180) return 'Average EV consumption';
    if (v < 250) return 'Larger SUV / winter conditions';
    return 'High consumption (e.g. Audi e-tron, Rivian)';
  }

  @override String get loading               => 'Loading...';
  @override String get clearLogTooltip       => 'Clear log';
  @override String get logCopiedSnackbar     => 'Log copied to clipboard';
  @override String get copyToClipboardTooltip => 'Copy to clipboard';

  @override String get disconnect            => 'Disconnect';
  @override String get powerLabel            => 'Power';
  @override String get speedLabel            => 'Speed';
  @override String get voltageLabel          => 'Voltage';
  @override String get currentLabel          => 'Current';
  @override String get aux12VLabel           => '12V battery';
  @override String get batteryMaxTempLabel   => 'Batt. max temp.';
  @override String get batteryMinTempLabel   => 'Batt. min temp.';
  @override String get operatingHoursLabel   => 'Op. hours';
  @override String get socDisplayLabel       => 'Charge (display)';
  @override String get socBmsLabel           => 'Charge (BMS)';
  @override String get sohLabel              => 'State (SOH)';
  @override String get remainingEnergyLabel  => 'Remaining energy';
  @override String get drivingParamsLabel    => 'Driving';
  @override String get statisticsLabel       => 'Statistics';
  @override String get maxChargePowerLabel   => 'Max charge pwr.';
  @override String get maxDischargePowerLabel => 'Max discharge pwr.';
  @override String get rangeEstimateLabel    => 'Range estimate';
  @override String get chartConsumptionLabel => 'Consumption';
  @override String get minCellVoltLabel      => 'Min cell voltage';
  @override String get maxCellVoltLabel      => 'Max cell voltage';
  @override String get avgCellVoltLabel      => 'Avg cell voltage';
  @override String get cellSpreadLabel       => 'Cell spread';

  @override String get chargingInProgress    => 'Charging in progress';
  @override String get elapsedPrefix         => 'Elapsed';
  @override String get chargingPowerLabel    => 'Charging power';
  @override String get energyAddedLabel      => 'Energy added';
  @override String get timeToFullLabel       => 'Time to 100%';
  @override String get chargingSpeedLabel    => 'Charging speed';
  @override String get chargingDetailsLabel  => 'Charging details';
  @override String get energyNeededToFullLabel => 'Energy to full';
  @override String get socBarTitle           => 'Charge (SOC)';
  @override String highBattTempWarning(double t) =>
      'High battery temperature: ${t.toStringAsFixed(0)}°C';
  @override String elevatedTempWarning(double t) =>
      'Elevated temperature: ${t.toStringAsFixed(0)}°C';

  @override String get dataCollectionInProgress => 'Collecting data...';

  @override String get chargeBarTitle        => 'CHARGE';
  @override String get rangeBarTitle         => 'RANGE (estimate)';
  @override String get cellsTitle            => 'CELLS';
  @override String get minCellLabel          => 'Min cell';
  @override String get maxCellLabel          => 'Max cell';
  @override String get avgCellLabel          => 'Avg cell';
  @override String get cellDiffLabel         => 'Difference (Δ)';
  @override String get lifeStatsTitle        => 'LIFETIME STATS';
  @override String get chargedKwhLabel       => 'Charged';
  @override String get dischargedKwhLabel    => 'Discharged';
  @override String get batteryDetailsLabel   => 'Battery details';
  @override String tempBasedRange(int t)     => 'based on ${t}°C';

  @override String get coolantLabel          => 'Coolant';
  @override String get intakeAirLabel        => 'Intake air';
  @override String get throttleLabel         => 'Throttle';
  @override String get aux12VShort           => 'Battery (12V)';
  @override String get boostPressureLabel    => 'Boost pressure';
  @override String get airMassFlowLabel      => 'Mass air flow (MAF)';
  @override String get obcLabel              => 'ON-BOARD COMPUTER';
  @override String get avgConsumptionLabel   => 'Avg fuel';
  @override String get instantConsumptionLabel => 'Instant fuel';
  @override String get distanceTravelledLabel => 'Distance';
  @override String get rangeLabel            => 'Range';
  @override String get noDtcLabel            => 'No active DTC';

  @override String get addChartTitle         => 'Add chart';
  @override String get noChartSelected       => 'No chart selected yet';
  @override String get addChartHint          => 'Press + to add\na chart';
  @override String get chartDataCollecting   => 'Collecting data...';

  @override String gpsPointsRecorded(int n)  => '$n GPS points recorded';
  @override String get tapForMap             => 'tap for map';
  @override String get routeLegend           => 'Route';
  @override String get tripStartLabel        => 'Start';
  @override String get tripEndLabel          => 'End';
  @override String get tripConsumptionPrefix => 'Consumption:';
  @override String get maxLabel              => 'Max:';
  @override String get avgLabel              => 'Avg:';

  @override String get cellDataCollectionInProgress => 'Collecting cell data...';
  @override String get fromAvgLabel          => 'from avg';

  @override String get kittCoolantBar        => 'COOLANT °C';
  @override String get kittFuelBar           => 'FUEL %';
  @override String get kittEngineLoadBar     => 'ENGINE LOAD %';
  @override String get kittIntakeBar         => 'INTAKE TEMP °C';
  @override String get kittThrottleCard      => 'THROTTLE';
  @override String get kittAux12VCard        => '12V BATTERY';
  @override String get kittIntakeCard        => 'INTAKE';

  @override String get sectionDriving        => 'DRIVING';
  @override String get sectionSoc            => 'STATE OF CHARGE';
  @override String get sectionVoltCurr       => 'VOLTAGE & CURRENT';
  @override String get sectionCells          => 'CELLS';
  @override String get sectionTemps          => 'TEMPERATURES';
  @override String get sectionBattHealth     => 'BATTERY HEALTH';
  @override String get sectionGasEngine      => 'GAS ENGINE';

  @override String get rangeEstShort         => 'Range (est.)';
  @override String get maxRangeLabel         => 'Max range';
  @override String get hvCurrLabel           => 'HV current';
  @override String get cellMinAvgMaxDelta    => 'Min / Avg / Max / Δ';
  @override String get coolantInLabel        => 'Coolant in';
  @override String get coolantOutLabel       => 'Coolant out';
  @override String get totalChargedLabel     => 'Total charged';
  @override String get totalDischargedLabel  => 'Total discharged';
  @override String get engineRpmSensLabel    => 'Engine speed';
  @override String get fuelLevelSensLabel    => 'Fuel level';
  @override String get coolantTempShortLabel => 'Coolant temp.';
  @override String moduleTempLabel(int n)    => 'Module $n';

  @override String get avgShortLabel         => 'Avg';

  @override String get chargeChartTitle      => 'Charge curve';
  @override String get chargeDataCollecting  => 'Collecting charge data...';

  @override String get autoModeDescription   =>
      'Measures actual consumption while driving '
      '(speed × power integration) and uses it '
      'for range estimation.\n'
      'While data is insufficient (< 500 m), '
      'applies the default 140 Wh/km value.';
  @override String get tempModeDescription   =>
      'Uses IP-based geolocation to retrieve the outdoor temperature '
      '(Open-Meteo API, 15-minute cache) and corrects '
      'the range estimate accordingly.\n'
      'Cold weather increases, warm weather decreases consumption.';

  @override String get dashFuelLabel         => 'FUEL';
  @override String get dashTempLabel         => 'TEMP';
  @override String get dashBattLabel         => 'BATT';
  @override String get dashVoltageLabel      => 'VOLTAGE';
  @override String get dashExtTempLabel      => 'EXT. TEMP';

  @override String get unknownDevice         => 'Unknown device';

  @override String get dbgNominalCapacity    => 'Nominal capacity';
  @override String get dbgActualCapacity     => 'Actual capacity';
  @override String get dbgLifetimeWhKm       => 'Lifetime Wh/km';
  @override String get dbgExternalTemp       => 'Outdoor temperature';
  @override String get dbgWhSource           => 'Wh/km source';
  @override String get dbgFinalWh            => 'Final Wh/km';
  @override String get dbgMaxRange           => 'Max range (100%)';
  @override String get dbgUnknown            => 'unknown';
  @override String get dbgNotEnoughData      => 'not enough data';
  @override String get dbgOdometerUnreadable => 'odometer unavailable';
  @override String get dbgDefault            => 'default';
  @override String dbgTripsLabel(int n)      => '$n trips';

  // ── OBD Monitor ───────────────────────────────────────────────────────────
  @override String get obdMonitorTitle       => 'OBD Monitor';
  @override String obdMonitorSubtitle(int n) => 'Raw traffic • $n entries';
  @override String get obdMonFilterHint      => 'Filter: 2248, 7E4, 62...';
  @override String get obdMonOnlyErrorsTip   => 'Errors / empty responses only';
  @override String get obdMonCopyTip         => 'Copy log to clipboard';
  @override String get obdMonDeleteTip       => 'Clear log';
  @override String get obdMonCopiedSnack     => 'Log copied to clipboard';
  @override String obdMonEntries(int n)      => '$n entries';
  @override String obdMonShown(int n)        => '↳ $n shown';
  @override String get obdMonOk              => 'OK';
  @override String get obdMonErr             => 'ERR';
  @override String get obdMonNoTraffic       =>
      'No OBD traffic yet.\nStart polling to see entries here.';
  @override String get obdMonNoMatch         => 'No entries match the filter.';
  @override String get obdMonNoResponse      => '(no response)';

  // ── Permissions & connection (UI) ─────────────────────────────────────────
  @override String get permissionsPermanentlyDenied =>
      'Bluetooth and location permissions are permanently denied.\n'
      'Enable them in the system settings to continue.';
  @override String get openAppSettings       => 'Open settings';
  @override String get bluetoothOffWarning   =>
      'Bluetooth is off. Turn it on to scan for devices.';
  @override String get reconnect             => 'Reconnect';
  @override String get reconnecting          => 'Reconnecting...';
  @override String get backOnceMore          => 'Press back again to exit';
  @override String get protocolLabel         => 'Protocol';
  @override String makeModelsLabel(String make) => '$make models';
}
