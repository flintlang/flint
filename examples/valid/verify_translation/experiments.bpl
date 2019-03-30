procedure Test()
{
  //assert (1 : int);
  //assert (exists x: int :: x == 1);
  assert (forall x: bool :: x == true || x == false);
  assert ((forall x: bool :: x == true || x == false) ==> (exists x: bool :: x == true));
  assert (exists x: bool :: x == true);
}
