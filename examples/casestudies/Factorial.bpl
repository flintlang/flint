var value: int;

procedure init_Factorial()
  modifies value;
{
  value := 0;
}

procedure factorial_Factorial(n: int) returns (result: int)
{
  var factorial_Factorial_result: int;
  if (n < 2) {
    result := 1;
    return;
  }

  call factorial_Factorial_result := factorial_Factorial(n - 1);
  result := n * factorial_Factorial_result;
}

procedure calculate_Factorial(n: int)
  modifies value;
{
  call value := factorial_Factorial(n);
}

procedure getValue_Factorial() returns (result: int)
{
  result := value;
}
