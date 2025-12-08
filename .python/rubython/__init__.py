from typing import Callable, Iterable


def tally[T](iterable: Iterable[T]) -> dict[T, int]:
	"""
	>>> tally('aaaabbc')
	{'a': 4, 'b': 2, 'c': 1}
	"""
	rv = {e: 0 for e in iterable}
	for e in iterable:
		rv[e] += 1
	return rv

def index[T](haystack: Iterable[T], needle: T | Callable[T, bool]) -> int:
	"""
	>>> index('aaab', 'c')
	Traceback (most recent call last):
	ValueError: substring not found
	>>> index('aaab', 'b')
	3
	>>> index([1, 2, 3], lambda x: x % 2 == 0)
	1
	"""
	if not callable(needle):
		return haystack.index(needle)
	for i, e in enumerate(haystack):
		if needle(e):
			return i
	raise ValueError('needle not found')
