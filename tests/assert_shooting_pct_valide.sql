-- Un pourcentage de reussite au tir hors [0, 1] signale une erreur de calcul en
-- amont (ex. shots_made > shots_attempted). Ce test echoue le build plutot que
-- de laisser l'incoherence se propager dans les analyses.

select *
from {{ ref('fct_shot_efficiency') }}
where fg_pct is not null
  and (fg_pct < 0 or fg_pct > 1)
