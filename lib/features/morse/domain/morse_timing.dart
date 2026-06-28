/// Morse timing as unit multiples — shared by SEND (sequence building) and
/// RECEIVE (pulse classification). One time-unit = `unitMs`.
class MorseTiming {
  const MorseTiming._();

  static const int dotUnits = 1;
  static const int dashUnits = 3;
  static const int symbolGapUnits = 1;
  static const int letterGapUnits = 3;
  static const int wordGapUnits = 7;
}
