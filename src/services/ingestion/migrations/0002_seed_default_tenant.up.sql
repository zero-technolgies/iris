INSERT INTO tenants (id, name)
VALUES ('00000000-0000-0000-0000-000000000001', 'Iris')
ON CONFLICT (id) DO NOTHING;

INSERT INTO contributors (
    id,
    tenant_id,
    type,
    display_name,
    external_refs
)
VALUES (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    'human',
    'Caleb',
    '{"github_username": "Calebache"}'::jsonb
)
ON CONFLICT (id) DO NOTHING;
