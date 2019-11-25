File.rm_rf!("test/tmp")

# Networking support has enough pieces that are singleton in nature
# that parallel running of tests can't be done.
ExUnit.start(max_cases: 1)
