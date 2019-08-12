type Address = int;
var lecturer: Address;
var markers: [int]Address;
var numMarkers: int;
var grades: [Address]int;

var caller: Address;

procedure Marking_init(lecturer_arg: Address)
  modifies lecturer;
{
  lecturer := lecturer_arg;
}

procedure Marking_addMarker(marker_arg: Address)
  requires caller == lecturer;
  modifies markers;
  modifies numMarkers;
  ensures caller == lecturer;
{
  markers[numMarkers] := marker_arg;
  numMarkers := numMarkers + 1;
}

procedure Marking_assignGrade(student: Address, grade: int)
  requires (exists x: int :: caller == markers[x]);
  requires grade > 0;
  modifies grades;
{
  grades[student] := grade;
  call Marking_assignGrade(student, grade);
}

procedure Marking_getGrade() returns (result: int)
{
  result := grades[caller];
}

procedure Test()
  ensures (exists x: int :: x == 1);
{
}
