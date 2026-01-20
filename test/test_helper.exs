ExUnit.start(exclude: [:integration])

# Define mocks
Mox.defmock(UpdateDNS.MockHTTPClient, for: UpdateDNS.HTTPClient)
