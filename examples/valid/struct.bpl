// To model objects -- This is Boogie 2
type Ref;
type Field a;
type HeapType = <a>[Ref, Field a]a;
var Heap: HeapType;

const unique C.data: Field int;
const unique C.next: Field Ref;
const alloc: Field bool;

// o.alloc() -> new C object C.alloc(Heap, o)
// o.next -> Heap[o, C.next]
function C.alloc(heap: HeapType) returns (Ref);
axiom (exists o: Ref :: !old(Heap)[o, alloc] && C.alloc(Heap) == o && Heap[o, alloc]);

procedure test()
  modifies Heap;
{
  var c1, c2, c3: Ref;
  c1 := C.alloc(Heap);
  c2 := C.alloc(Heap);
  c3 := C.alloc(Heap);

  Heap[c1, C.next] := c2;
  Heap[c2, C.next] := c1;
  assert (forall x: Ref :: (exists y: Ref :: Heap[x, C.next] == y && Heap[y, C.next] == x));
}
