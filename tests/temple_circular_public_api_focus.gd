extends SceneTree

func _initialize() -> void:
	LibrarySuite._quick = true
	LibrarySuite._cache.clear()
	var requests: Array[BuildingRequest] = [
		BuildingRequest.church(901, &"gothic", 10.0, 22.0, 12.0),
		BuildingRequest.temple(902, &"basilica", &"blood", 26.0, 44.0, 12.0),
		BuildingRequest.temple(903, &"rotunda", &"serpent", 18.0, 24.0, 8.0),
	]
	var result := SuiteResult.new("temple-basilica-api-focus")
	for request in requests:
		LibrarySuite._check_family(result, request)
	LibrarySuite._check_contract(result, requests)
	LibrarySuite._check_documents(result, requests)
	LibrarySuite._notes(result)
	print(result.summary())
	for failure in result.failures:
		push_error(failure)
	quit(0 if result.ok() else 1)
