set syntax_linkage(alter-table-stmt) {column-def sql-stmt}
set syntax_linkage(analyze-stmt) {{} sql-stmt}
set syntax_linkage(attach-stmt) {expr sql-stmt}
set syntax_linkage(begin-stmt) {{} sql-stmt}
set syntax_linkage(column-constraint) {{conflict-clause expr foreign-key-clause literal-value signed-number} column-def}
set syntax_linkage(column-def) {{column-constraint type-name} {alter-table-stmt create-table-stmt}}
set syntax_linkage(column-name-list) {{} {update-stmt update-stmt-limited}}
set syntax_linkage(comment-syntax) {{} {}}
set syntax_linkage(commit-stmt) {{} sql-stmt}
set syntax_linkage(common-table-expression) {select-stmt {compound-select-stmt factored-select-stmt select-stmt simple-select-stmt}}
set syntax_linkage(compound-operator) {{} {factored-select-stmt select-stmt}}
set syntax_linkage(compound-select-stmt) {{common-table-expression expr ordering-term select-core} {}}
set syntax_linkage(conflict-clause) {{} {column-constraint table-constraint}}
set syntax_linkage(create-index-stmt) {{expr indexed-column} sql-stmt}
set syntax_linkage(create-table-stmt) {{column-def select-stmt table-constraint} sql-stmt}
set syntax_linkage(create-trigger-stmt) {{delete-stmt expr insert-stmt select-stmt update-stmt} sql-stmt}
set syntax_linkage(create-view-stmt) {select-stmt sql-stmt}
set syntax_linkage(create-virtual-table-stmt) {{} sql-stmt}
set syntax_linkage(cte-table-name) {{} {recursive-cte with-clause}}
set syntax_linkage(delete-stmt) {{expr qualified-table-name with-clause} {create-trigger-stmt sql-stmt}}
set syntax_linkage(delete-stmt-limited) {{expr ordering-term qualified-table-name with-clause} sql-stmt}
set syntax_linkage(detach-stmt) {{} sql-stmt}
set syntax_linkage(drop-index-stmt) {{} sql-stmt}
set syntax_linkage(drop-table-stmt) {{} sql-stmt}
set syntax_linkage(drop-trigger-stmt) {{} sql-stmt}
set syntax_linkage(drop-view-stmt) {{} sql-stmt}
set syntax_linkage(expr) {{literal-value raise-function select-stmt type-name} {attach-stmt column-constraint compound-select-stmt create-index-stmt create-trigger-stmt delete-stmt delete-stmt-limited factored-select-stmt indexed-column insert-stmt join-constraint ordering-term result-column select-core select-stmt simple-select-stmt table-constraint table-or-subquery update-stmt update-stmt-limited}}
set syntax_linkage(factored-select-stmt) {{common-table-expression compound-operator expr ordering-term select-core} {}}
set syntax_linkage(foreign-key-clause) {{} {column-constraint table-constraint}}
set syntax_linkage(indexed-column) {expr {create-index-stmt table-constraint}}
set syntax_linkage(insert-stmt) {{expr select-stmt with-clause} {create-trigger-stmt sql-stmt}}
set syntax_linkage(join-clause) {{join-constraint join-operator table-or-subquery} {select-core select-stmt table-or-subquery}}
set syntax_linkage(join-constraint) {expr join-clause}
set syntax_linkage(join-operator) {{} join-clause}
set syntax_linkage(literal-value) {{} {column-constraint expr}}
set syntax_linkage(numeric-literal) {{} {}}
set syntax_linkage(ordering-term) {expr {compound-select-stmt delete-stmt-limited factored-select-stmt select-stmt simple-select-stmt update-stmt-limited}}
set syntax_linkage(pragma-stmt) {pragma-value sql-stmt}
set syntax_linkage(pragma-value) {signed-number pragma-stmt}
set syntax_linkage(qualified-table-name) {{} {delete-stmt delete-stmt-limited update-stmt update-stmt-limited}}
set syntax_linkage(raise-function) {{} expr}
set syntax_linkage(recursive-cte) {cte-table-name {}}
set syntax_linkage(reindex-stmt) {{} sql-stmt}
set syntax_linkage(release-stmt) {{} sql-stmt}
set syntax_linkage(result-column) {expr {select-core select-stmt}}
set syntax_linkage(rollback-stmt) {{} sql-stmt}
set syntax_linkage(savepoint-stmt) {{} sql-stmt}
set syntax_linkage(select-core) {{expr join-clause result-column table-or-subquery} {compound-select-stmt factored-select-stmt simple-select-stmt}}
set syntax_linkage(select-stmt) {{common-table-expression compound-operator expr join-clause ordering-term result-column table-or-subquery} {common-table-expression create-table-stmt create-trigger-stmt create-view-stmt expr insert-stmt sql-stmt table-or-subquery with-clause}}
set syntax_linkage(signed-number) {{} {column-constraint pragma-value type-name}}
set syntax_linkage(simple-select-stmt) {{common-table-expression expr ordering-term select-core} {}}
set syntax_linkage(sql-stmt) {{alter-table-stmt analyze-stmt attach-stmt begin-stmt commit-stmt create-index-stmt create-table-stmt create-trigger-stmt create-view-stmt create-virtual-table-stmt delete-stmt delete-stmt-limited detach-stmt drop-index-stmt drop-table-stmt drop-trigger-stmt drop-view-stmt insert-stmt pragma-stmt reindex-stmt release-stmt rollback-stmt savepoint-stmt select-stmt update-stmt update-stmt-limited vacuum-stmt} sql-stmt-list}
set syntax_linkage(sql-stmt-list) {sql-stmt {}}
set syntax_linkage(table-constraint) {{conflict-clause expr foreign-key-clause indexed-column} create-table-stmt}
set syntax_linkage(table-or-subquery) {{expr join-clause select-stmt} {join-clause select-core select-stmt}}
set syntax_linkage(type-name) {signed-number {column-def expr}}
set syntax_linkage(update-stmt) {{column-name-list expr qualified-table-name with-clause} {create-trigger-stmt sql-stmt}}
set syntax_linkage(update-stmt-limited) {{column-name-list expr ordering-term qualified-table-name with-clause} sql-stmt}
set syntax_linkage(vacuum-stmt) {{} sql-stmt}
set syntax_linkage(with-clause) {{cte-table-name select-stmt} {delete-stmt delete-stmt-limited insert-stmt update-stmt update-stmt-limited}}
set syntax_order {sql-stmt-list sql-stmt alter-table-stmt analyze-stmt attach-stmt begin-stmt commit-stmt rollback-stmt savepoint-stmt release-stmt create-index-stmt indexed-column create-table-stmt column-def type-name column-constraint signed-number table-constraint foreign-key-clause conflict-clause create-trigger-stmt create-view-stmt create-virtual-table-stmt with-clause cte-table-name recursive-cte common-table-expression delete-stmt delete-stmt-limited detach-stmt drop-index-stmt drop-table-stmt drop-trigger-stmt drop-view-stmt expr raise-function literal-value numeric-literal insert-stmt pragma-stmt pragma-value reindex-stmt select-stmt join-clause select-core factored-select-stmt simple-select-stmt compound-select-stmt table-or-subquery result-column join-operator join-constraint ordering-term compound-operator update-stmt column-name-list update-stmt-limited qualified-table-name vacuum-stmt comment-syntax}
