# SqlSpecHelper

`spec/spec_helper.rb`

```ruby
require 'sql_spec_helper'

# Add `$sql`, `DB`, `run_sql`, `compare_with`, and `Display` to main for backwards compatibility.
$sql_spec_helper = SqlSpecHelper.new('/workspace/solution.txt')
$sql = $sql_spec_helper.sql
DB = $sql_spec_helper.db
def run_sql(...)
  $sql_spec_helper.run_sql(...)
end
def compare_with(...)
  $sql_spec_helper.compare_with(...)
end
Display = SqlSpecHelper::Display
```
