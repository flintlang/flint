//axiom (forall x, y: int :: {x % y} {x / y} x % y == x - x / y * y);
//axiom (forall x: int :: forall y: int :: {x % y} (0 < y ==> 0 <= x % y && x % y < y) && (y < 0 ==> y < x % y && x % y <= 0));
//axiom (forall x, y: int :: x % y == x - x / y * y);
//axiom (forall x, y: int :: (0 < y ==> 0 <= x % y && x % y < y) && (y < 0 ==> y < x % y && x % y <= 0));

function f(i: int) returns (int);
axiom (forall j: int :: f(j) == 42 * j);

var c: int;

procedure a (a: int, b: int)
  requires (a >= b);
  requires (b >= c);
  ensures (f(a) >= f(c));
{}

var sum: int;
var count: int;

procedure avg() returns (avg: int)
  requires (count > 0);
  requires (sum > 0);
  ensures (avg >= 0);
{
  avg := int(sum / count);
  assert (1 div 2 == );
}

//function div(n: int, d: int) returns (result: real);
//function mod(n: int, m: int) returns (result: real);
