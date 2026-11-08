-- =============================================================================
-- Data-preservation snapshot / verification (test-only, schema `test_meta`).
--
-- snapshot: records row count and an md5 checksum of every row, per public
--           table, over the columns that exist at snapshot time.
-- verify:   recomputes over the SAME columns and raises if anything changed,
--           so additive migrations (new columns/tables) must leave existing
--           data byte-for-byte identical.
--
-- Usage: psql -v mode=snapshot -f data_snapshot.sql
--        psql -v mode=verify   -f data_snapshot.sql
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS test_meta;

CREATE OR REPLACE FUNCTION test_meta.table_checksum(tbl text, cols text[])
RETURNS TABLE (row_count bigint, checksum text)
LANGUAGE plpgsql AS $$
DECLARE
    col_list text;
BEGIN
    SELECT string_agg(format('%I', c), ', ' ORDER BY ord)
    INTO col_list
    FROM unnest(cols) WITH ORDINALITY AS u(c, ord);

    RETURN QUERY EXECUTE format(
        'SELECT count(*)::bigint, md5(coalesce(string_agg(r, %L ORDER BY r), %L))
           FROM (SELECT (ROW(%s))::text AS r FROM public.%I) s',
        '|', '', col_list, tbl
    );
END
$$;

CREATE TABLE IF NOT EXISTS test_meta.snapshot (
    table_name text PRIMARY KEY,
    cols text[] NOT NULL,
    row_count bigint NOT NULL,
    checksum text NOT NULL
);

\if :{?mode}
\else
\set mode snapshot
\endif

SELECT :'mode' = 'snapshot' AS is_snapshot \gset

\if :is_snapshot
TRUNCATE test_meta.snapshot;

INSERT INTO test_meta.snapshot (table_name, cols, row_count, checksum)
SELECT t.table_name, c.cols, s.row_count, s.checksum
FROM information_schema.tables t
CROSS JOIN LATERAL (
    SELECT array_agg(column_name::text ORDER BY ordinal_position) AS cols
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = t.table_name
) c
CROSS JOIN LATERAL test_meta.table_checksum(t.table_name, c.cols) s
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE';

SELECT format('snapshot: %s tables, %s rows', count(*), sum(row_count)) AS result
FROM test_meta.snapshot;
\else
DO $$
DECLARE
    rec record;
    now_count bigint;
    now_sum text;
    problems text := '';
BEGIN
    FOR rec IN SELECT * FROM test_meta.snapshot ORDER BY table_name LOOP
        IF to_regclass('public.' || quote_ident(rec.table_name)) IS NULL THEN
            problems := problems || format(' %s: table missing;', rec.table_name);
            CONTINUE;
        END IF;

        SELECT row_count, checksum INTO now_count, now_sum
        FROM test_meta.table_checksum(rec.table_name, rec.cols);

        IF now_count <> rec.row_count OR now_sum <> rec.checksum THEN
            problems := problems || format(' %s: rows %s -> %s;',
                rec.table_name, rec.row_count, now_count);
        END IF;
    END LOOP;

    IF problems <> '' THEN
        RAISE EXCEPTION 'not ok - data preservation:%', problems;
    END IF;

    RAISE NOTICE 'ok - data preservation: % tables, % rows unchanged',
        (SELECT count(*) FROM test_meta.snapshot),
        (SELECT sum(row_count) FROM test_meta.snapshot);
END
$$;
\endif
