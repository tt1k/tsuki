# tsuki DB Init

使用以下脚本初始化本地 PostgreSQL 数据库（数据库名：`tsuki`）：

```bash
bash code/be/tsuki-api/scripts/db/init_tsuki_db.sh
```

如果你要重置本地数据库（删除并重建）：

```bash
bash code/be/tsuki-api/scripts/db/init_tsuki_db.sh --force-recreate
```

脚本行为：

- 如果 `tsuki` 不存在，则自动创建
- 如果 `tsuki` 已存在，则跳过创建
- 传入 `--force-recreate` 时，会先删除再重建
- 执行建表 SQL：`code/be/tsuki-api/scripts/db/init_tsuki_db.sql`

也可以手动执行 SQL 文件：

```bash
psql -d tsuki -f code/be/tsuki-api/scripts/db/init_tsuki_db.sql
```
