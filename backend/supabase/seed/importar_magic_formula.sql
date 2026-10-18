-- Importa las 5 mediciones de los informes de Magic Formula (2021–2022)
-- a la cuenta con este correo. Ejecutar UNA vez en Supabase → SQL Editor,
-- después de crear la cuenta en la app. Si se repite, no duplica nada.

with u as (
  select id from auth.users where email = 'jrgguevara15@gmail.com'
)
insert into public.measurements
  (user_id, measured_on, weight_kg, neck_cm, waist_cm, reported_fat_pct, source)
select u.id, m.measured_on, m.weight_kg, m.neck_cm, m.waist_cm, m.reported_fat_pct, m.source
from u, (values
  (date '2021-08-02', 116.4, 46, 112, 28.79, 'Nutri · Dieta 01'),
  (date '2021-09-08', 114.8, 45, 109, 27.61, 'Nutri · Dieta 02'),
  (date '2021-10-06', 114.6, 45, 107, 26.40, 'Nutri · Dieta 02'),
  (date '2021-12-17', 110.9, 44, 105, 25.78, 'Nutri · Dieta 03'),
  (date '2022-02-23', 110.9, 44, 102, 18.74, 'Nutri · Dieta 04')
) as m(measured_on, weight_kg, neck_cm, waist_cm, reported_fat_pct, source)
on conflict (user_id, measured_on) do nothing;

-- Comprobar:
-- select measured_on, weight_kg, waist_cm, source from public.measurements
-- order by measured_on;
