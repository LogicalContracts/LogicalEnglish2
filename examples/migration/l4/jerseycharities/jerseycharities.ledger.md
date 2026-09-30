# Migration ledger: jerseycharities

Source: an L4 program (smucclaw/l4-ide) — jerseyCharities.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 123 |
| approximated | 112 |
| residue | 3 |
| **total** | 238 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Purpose | type | encoded | a type | Purpose |  |
| Entity | record | encoded | a type of individuals, one template per field | Entity |  |
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| Governor | record | encoded | a type of individuals, one template per field | Governor |  |
| RegisterSection | choice | encoded | named individuals | RegisterSection |  |
| Date | record | encoded | a type of individuals, one template per field | Date |  |
| Place | record | encoded | a type of individuals, one template per field | Place |  |
| CharitablePurpose | choice | encoded | named individuals | CharitablePurpose |  |
| charitable purpose | wording | approximated | the template's words made from the name, its inputs appended | charitable purpose for *a purpose* | to be reviewed: the name does not say where its inputs go |
| ancillary or incidental to charitable purpose | wording | approximated | the template's words made from the name, its inputs appended | ancillary else incidental to charitable purpose for *a purpose* | to be reviewed: the name does not say where its inputs go |
| provides public benefit in Jersey or elsewhere | wording | approximated | the template's words made from the name, its inputs appended | *an entity* provides public benefit in jersey else elsewhere | to be reviewed: the name does not say where its inputs go |
| is a Jersey entity | wording | approximated | the template's words made from the name, its inputs appended | *an entity* is a jersey entity | to be reviewed: the name does not say where its inputs go |
| carries out substantial activity in Jersey | wording | approximated | the template's words made from the name, its inputs appended | carries out substantial activity in jersey for *an entity* | to be reviewed: the name does not say where its inputs go |
| has a principal address in Jersey | wording | approximated | the template's words made from the name, its inputs appended | *an entity* has a principal address in jersey | to be reviewed: the name does not say where its inputs go |
| constitution | wording | approximated | the template's words made from the name, its inputs appended | the constitution for *an entity* is *a constitution* | to be reviewed: the name does not say where its inputs go |
| is a written document | wording | approximated | the template's words made from the name, its inputs appended | *a constitution* is a written document | to be reviewed: the name does not say where its inputs go |
| name | wording | approximated | the template's words made from the name, its inputs appended | the name for *an entity* is *a name* | to be reviewed: the name does not say where its inputs go |
| is undesirable | wording | approximated | the template's words made from the name, its inputs appended | *a x10* is undesirable | to be reviewed: the name does not say where its inputs go |
| same as another charity | wording | approximated | the template's words made from the name, its inputs appended | same as another charity for *a x11* | to be reviewed: the name does not say where its inputs go |
| too similar to another charity | wording | approximated | the template's words made from the name, its inputs appended | too similar to another charity for *a x12* | to be reviewed: the name does not say where its inputs go |
| misleading | wording | approximated | the template's words made from the name, its inputs appended | misleading for *a x13* | to be reviewed: the name does not say where its inputs go |
| implies false connection | wording | approximated | the template's words made from the name, its inputs appended | implies false connection for *a x14* | to be reviewed: the name does not say where its inputs go |
| offensive | wording | approximated | the template's words made from the name, its inputs appended | offensive for *a x15* | to be reviewed: the name does not say where its inputs go |
| is governor of | wording | approximated | the template's words made from the name, its inputs appended | *a x16* is governor of for *a x17* | to be reviewed: the name does not say where its inputs go |
| directed by Minister | wording | approximated | the template's words made from the name, its inputs appended | directed by minister for *a x18* | to be reviewed: the name does not say where its inputs go |
| directed by States Assembly member | wording | approximated | the template's words made from the name, its inputs appended | directed by states assembly member for *a x19* | to be reviewed: the name does not say where its inputs go |
| directed by equivalent in another jurisdiction | wording | approximated | the template's words made from the name, its inputs appended | directed by equivalent in another jurisdiction for *a x20* | to be reviewed: the name does not say where its inputs go |
| is registered | wording | approximated | the template's words made from the name, its inputs appended | *a x21* is registered | to be reviewed: the name does not say where its inputs go |
| is deregistered | wording | approximated | the template's words made from the name, its inputs appended | *a x22* is deregistered | to be reviewed: the name does not say where its inputs go |
| registration date | wording | approximated | the template's words made from the name, its inputs appended | the registration date for *a x23* is *a date* | to be reviewed: the name does not say where its inputs go |
| deregistration date | wording | approximated | the template's words made from the name, its inputs appended | the deregistration date for *a x24* is *a date* | to be reviewed: the name does not say where its inputs go |
| registration section | wording | approximated | the template's words made from the name, its inputs appended | the registration section for *a x25* is *a register section* | to be reviewed: the name does not say where its inputs go |
| applied for registration | wording | approximated | the template's words made from the name, its inputs appended | applied for registration for *a x26* | to be reviewed: the name does not say where its inputs go |
| applied for deregistration | wording | approximated | the template's words made from the name, its inputs appended | applied for deregistration for *a x27* | to be reviewed: the name does not say where its inputs go |
| registration refused | wording | approximated | the template's words made from the name, its inputs appended | registration refused for *a x28* | to be reviewed: the name does not say where its inputs go |
| applied to change name | wording | approximated | the template's words made from the name, its inputs appended | applied to change name for *a x29* | to be reviewed: the name does not say where its inputs go |
| name change refused | wording | approximated | the template's words made from the name, its inputs appended | name change refused for *a x30* | to be reviewed: the name does not say where its inputs go |
| meets funding condition | wording | approximated | the template's words made from the name, its inputs appended | *a x31* meets funding condition | to be reviewed: the name does not say where its inputs go |
| refrains from soliciting donations | wording | approximated | the template's words made from the name, its inputs appended | refrains from soliciting donations for *a x32* | to be reviewed: the name does not say where its inputs go |
| requested restricted section | wording | approximated | the template's words made from the name, its inputs appended | requested restricted section for *a x33* | to be reviewed: the name does not say where its inputs go |
| acts with due diligence | wording | approximated | the template's words made from the name, its inputs appended | acts with due diligence for *a x34* with *a x35* | to be reviewed: the name does not say where its inputs go |
| acts as prudent person | wording | approximated | the template's words made from the name, its inputs appended | acts as prudent person for *a x36* with *a x37* | to be reviewed: the name does not say where its inputs go |
| acts to best ability | wording | approximated | the template's words made from the name, its inputs appended | acts to best ability for *a x38* with *a x39* | to be reviewed: the name does not say where its inputs go |
| observes good faith | wording | approximated | the template's words made from the name, its inputs appended | observes good faith for *a x40* with *a x41* | to be reviewed: the name does not say where its inputs go |
| ensures consistency with purposes | wording | approximated | the template's words made from the name, its inputs appended | ensures consistency with purposes for *a x42* with *a x43* | to be reviewed: the name does not say where its inputs go |
| ensures compliance with law | wording | approximated | the template's words made from the name, its inputs appended | ensures compliance with law for *a x44* with *a x45* | to be reviewed: the name does not say where its inputs go |
| reportable matter exists | wording | approximated | the template's words made from the name, its inputs appended | reportable matter exists for *a x46* | to be reviewed: the name does not say where its inputs go |
| reported to charity | wording | approximated | the template's words made from the name, its inputs appended | reported to charity for *a x47* with *a x48* | to be reviewed: the name does not say where its inputs go |
| reported to Commissioner | wording | approximated | the template's words made from the name, its inputs appended | reported to commissioner for *a x49* | to be reviewed: the name does not say where its inputs go |
| declared no reportable matters | wording | approximated | the template's words made from the name, its inputs appended | declared no reportable matters for *a x50* with *a x51* | to be reviewed: the name does not say where its inputs go |
| is fit and proper person | wording | approximated | the template's words made from the name, its inputs appended | *a x52* is fit as well as proper person | to be reviewed: the name does not say where its inputs go |
| provides annual return | wording | approximated | the template's words made from the name, its inputs appended | *a x53* provides annual return | to be reviewed: the name does not say where its inputs go |
| reports changes | wording | approximated | the template's words made from the name, its inputs appended | reports changes for *a x54* | to be reviewed: the name does not say where its inputs go |
| applies property per purposes | wording | approximated | the template's words made from the name, its inputs appended | applies property per purposes for *a x55* | to be reviewed: the name does not say where its inputs go |
| applies property per statement | wording | approximated | the template's words made from the name, its inputs appended | applies property per statement for *a x56* | to be reviewed: the name does not say where its inputs go |
| amended to non-charitable purpose | wording | approximated | the template's words made from the name, its inputs appended | amended to non charitable purpose for *a x57* | to be reviewed: the name does not say where its inputs go |
| changed name without permission | wording | approximated | the template's words made from the name, its inputs appended | changed name without permission for *a x58* | to be reviewed: the name does not say where its inputs go |
| uses other than registered name | wording | approximated | the template's words made from the name, its inputs appended | uses other than registered name for *a x59* | to be reviewed: the name does not say where its inputs go |
| amended purposes without approval | wording | approximated | the template's words made from the name, its inputs appended | amended purposes without approval for *a x60* | to be reviewed: the name does not say where its inputs go |
| amended statement without approval | wording | approximated | the template's words made from the name, its inputs appended | amended statement without approval for *a x61* | to be reviewed: the name does not say where its inputs go |
| required steps notice served | wording | approximated | the template's words made from the name, its inputs appended | required steps notice served for *a x62* | to be reviewed: the name does not say where its inputs go |
| notice served on governor | wording | approximated | the template's words made from the name, its inputs appended | notice served on governor for *a x63* | to be reviewed: the name does not say where its inputs go |
| complied with notice | wording | approximated | the template's words made from the name, its inputs appended | complied with notice for *a x64* | to be reviewed: the name does not say where its inputs go |
| disqualification order exists | wording | approximated | the template's words made from the name, its inputs appended | disqualification order exists for *a x65* | to be reviewed: the name does not say where its inputs go |
| refers to as charity | wording | approximated | the template's words made from the name, its inputs appended | refers to as charity for *a x66* with *a x67* | to be reviewed: the name does not say where its inputs go |
| refers to as Jersey charity | wording | approximated | the template's words made from the name, its inputs appended | refers to as jersey charity for *a x68* with *a x69* | to be reviewed: the name does not say where its inputs go |
| refers to as registered | wording | approximated | the template's words made from the name, its inputs appended | refers to as registered for *a x70* with *a x71* | to be reviewed: the name does not say where its inputs go |
| knows not registered | wording | approximated | the template's words made from the name, its inputs appended | knows not registered for *a x72* with *a x73* | to be reviewed: the name does not say where its inputs go |
| intends to mislead | wording | approximated | the template's words made from the name, its inputs appended | intends to mislead for *a x74* with *a x75* | to be reviewed: the name does not say where its inputs go |
| intends to gain advantage | wording | approximated | the template's words made from the name, its inputs appended | intends to gain advantage for *a x76* with *a x77* | to be reviewed: the name does not say where its inputs go |
| misconduct | wording | approximated | the template's words made from the name, its inputs appended | misconduct for *a x78* | to be reviewed: the name does not say where its inputs go |
| governor misconduct | wording | approximated | the template's words made from the name, its inputs appended | governor misconduct for *a x79* | to be reviewed: the name does not say where its inputs go |
| governor reportable matter | wording | approximated | the template's words made from the name, its inputs appended | governor reportable matter for *a x80* | to be reviewed: the name does not say where its inputs go |
| misled Commissioner | wording | approximated | the template's words made from the name, its inputs appended | misled commissioner for *a x81* | to be reviewed: the name does not say where its inputs go |
| no longer exists | wording | approximated | the template's words made from the name, its inputs appended | no longer exists for *a x82* | to be reviewed: the name does not say where its inputs go |
| governor of registered charity | wording | approximated | the template's words made from the name, its inputs appended | governor of registered charity for *a x83* | to be reviewed: the name does not say where its inputs go |
| wholly managed in Jersey | wording | approximated | the template's words made from the name, its inputs appended | wholly managed in jersey for *a x84* | to be reviewed: the name does not say where its inputs go |
| excepted foreign charity | wording | approximated | the template's words made from the name, its inputs appended | excepted foreign charity for *a x85* | to be reviewed: the name does not say where its inputs go |
| established under UK law | wording | approximated | the template's words made from the name, its inputs appended | established under UK law for *a x86* | to be reviewed: the name does not say where its inputs go |
| established under prescribed law | wording | approximated | the template's words made from the name, its inputs appended | established under prescribed law for *a x87* | to be reviewed: the name does not say where its inputs go |
| entitled to use charity term | wording | approximated | the template's words made from the name, its inputs appended | entitled to use charity term for *a x88* | to be reviewed: the name does not say where its inputs go |
| managed from establishment jurisdiction | wording | approximated | the template's words made from the name, its inputs appended | managed from establishment jurisdiction for *a x89* | to be reviewed: the name does not say where its inputs go |
| may appeal to tribunal | wording | approximated | the template's words made from the name, its inputs appended | *a x90* may appeal to tribunal for *a x91* | to be reviewed: the name does not say where its inputs go |
| may appeal to court | wording | approximated | the template's words made from the name, its inputs appended | *a x92* may appeal to court for *a x93* | to be reviewed: the name does not say where its inputs go |
| is required steps notice | wording | approximated | the template's words made from the name, its inputs appended | *a x94* is required steps notice | to be reviewed: the name does not say where its inputs go |
| is deregistration decision | wording | approximated | the template's words made from the name, its inputs appended | *a x95* is deregistration decision | to be reviewed: the name does not say where its inputs go |
| is registration refusal | wording | approximated | the template's words made from the name, its inputs appended | *a x96* is registration refusal | to be reviewed: the name does not say where its inputs go |
| is name change refusal | wording | approximated | the template's words made from the name, its inputs appended | *a x97* is name change refusal | to be reviewed: the name does not say where its inputs go |
| organized religious charity | wording | approximated | the template's words made from the name, its inputs appended | organized religious charity for *a x98* | to be reviewed: the name does not say where its inputs go |
| acquired before deregistration | wording | approximated | the template's words made from the name, its inputs appended | acquired before deregistration for *a x99* | to be reviewed: the name does not say where its inputs go |
| preserved charitable purposes | wording | approximated | the template's words made from the name, its inputs appended | the preserved charitable purposes for *a x100* is *a purpose* | to be reviewed: the name does not say where its inputs go |
| preserved public benefit statement | wording | approximated | the template's words made from the name, its inputs appended | the preserved public benefit statement for *a x101* is *a statement* | to be reviewed: the name does not say where its inputs go |
| isBOT | wording | approximated | the template's words made from the name, its inputs appended | *a place* is BOT | to be reviewed: the name does not say where its inputs go |
| qualifying territory | wording | approximated | the template's words made from the name, its inputs appended | qualifying territory for *a place* | to be reviewed: the name does not say where its inputs go |
| is ancillary | wording | approximated | the template's words made from the name, its inputs appended | *a x102* is ancillary | to be reviewed: the name does not say where its inputs go |
| is analogous to charitable purpose | wording | approximated | the template's words made from the name, its inputs appended | *a x103* is analogous to charitable purpose | to be reviewed: the name does not say where its inputs go |
| meets the charity test | wording | approximated | the template's words made from the name, its inputs appended | *an entity* meets the charity test | to be reviewed: the name does not say where its inputs go |
| eligible for registration as charity | wording | approximated | the template's words made from the name, its inputs appended | eligible for registration as charity for *an entity* | to be reviewed: the name does not say where its inputs go |
| is undesirable | wording | approximated | the template's words made from the name, its inputs appended | *a name* is undesirable variant one | to be reviewed: the name does not say where its inputs go |
| eligible for restricted section | wording | approximated | the template's words made from the name, its inputs appended | eligible for restricted section for *an entity* | to be reviewed: the name does not say where its inputs go |
| complies with requirements | wording | approximated | the template's words made from the name, its inputs appended | complies with requirements for *an entity* | to be reviewed: the name does not say where its inputs go |
| fulfills governor duties | wording | approximated | the template's words made from the name, its inputs appended | fulfills governor duties for *a person* with *an entity* | to be reviewed: the name does not say where its inputs go |
| may refer to as Jersey charity | wording | approximated | the template's words made from the name, its inputs appended | *an entity* may refer to as jersey charity for *an user* | to be reviewed: the name does not say where its inputs go |
| may refer to as charity | wording | approximated | the template's words made from the name, its inputs appended | *an entity* may refer to as charity for *an user* | to be reviewed: the name does not say where its inputs go |
| excepted foreign charity | wording | approximated | the template's words made from the name, its inputs appended | excepted foreign charity for *an entity* variant two | to be reviewed: the name does not say where its inputs go |
| may issue required steps notice | wording | approximated | the template's words made from the name, its inputs appended | *an entity* may issue required steps notice | to be reviewed: the name does not say where its inputs go |
| may deregister | wording | approximated | the template's words made from the name, its inputs appended | *an entity* may deregister | to be reviewed: the name does not say where its inputs go |
| must apply property for preserved purposes | wording | approximated | the template's words made from the name, its inputs appended | *an entity* must apply *a property* for preserved purposes | to be reviewed: the name does not say where its inputs go |
| may appeal to tribunal | wording | approximated | the template's words made from the name, its inputs appended | *an entity* may appeal to tribunal for *a decision* variant three | to be reviewed: the name does not say where its inputs go |
| in public register | wording | approximated | the template's words made from the name, its inputs appended | in public register for *a x104* | to be reviewed: the name does not say where its inputs go |
| general section | wording | approximated | the template's words made from the name, its inputs appended | general section for *a x105* | to be reviewed: the name does not say where its inputs go |
| restricted section public elements | wording | approximated | the template's words made from the name, its inputs appended | restricted section public elements for *a x106* | to be reviewed: the name does not say where its inputs go |
| historic section | wording | approximated | the template's words made from the name, its inputs appended | historic section for *a x107* | to be reviewed: the name does not say where its inputs go |
| disclosure to authorized person | wording | approximated | the template's words made from the name, its inputs appended | disclosure to authorized person for *a x108* | to be reviewed: the name does not say where its inputs go |
| for investigation of offense | wording | approximated | the template's words made from the name, its inputs appended | for investigation of offense for *a x109* | to be reviewed: the name does not say where its inputs go |
| for legal proceedings | wording | approximated | the template's words made from the name, its inputs appended | for legal proceedings for *a x110* | to be reviewed: the name does not say where its inputs go |
| may disclose | wording | approximated | the template's words made from the name, its inputs appended | *a person* may disclose for *an info* | to be reviewed: the name does not say where its inputs go |
| may require governor removal | wording | approximated | the template's words made from the name, its inputs appended | *an entity* may require governor removal for *a notice* | to be reviewed: the name does not say where its inputs go |
| Billy | record | encoded | an individual with one fact per field | billy |  |
| William Farquhar | record | encoded | an individual with one fact per field | william_farquhar |  |
| commencement | record | encoded | an individual with one fact per field | commencement |  |
| appointed day | record | encoded | an individual with one fact per field | appointed_day |  |
| charitable purpose | assume | encoded | a template the scenarios state (; undefined) | charitable purpose |  |
| ancillary or incidental to charitable purpose | assume | encoded | a template the scenarios state (; undefined) | ancillary or incidental to charitable purpose |  |
| provides public benefit in Jersey or elsewhere | assume | encoded | a template the scenarios state (; undefined) | provides public benefit in Jersey or elsewhere |  |
| is a Jersey entity | assume | encoded | a template the scenarios state (; undefined) | is a Jersey entity |  |
| carries out substantial activity in Jersey | assume | encoded | a template the scenarios state (; undefined) | carries out substantial activity in Jersey |  |
| has a principal address in Jersey | assume | encoded | a template the scenarios state (; undefined) | has a principal address in Jersey |  |
| constitution | assume | encoded | a template the scenarios state (; undefined) | constitution |  |
| is a written document | assume | encoded | a template the scenarios state (; undefined) | is a written document |  |
| name | assume | encoded | a template the scenarios state (; undefined) | name |  |
| is undesirable | assume | encoded | a template the scenarios state (; undefined) | is undesirable |  |
| same as another charity | assume | encoded | a template the scenarios state (; undefined) | same as another charity |  |
| too similar to another charity | assume | encoded | a template the scenarios state (; undefined) | too similar to another charity |  |
| misleading | assume | encoded | a template the scenarios state (; undefined) | misleading |  |
| implies false connection | assume | encoded | a template the scenarios state (; undefined) | implies false connection |  |
| offensive | assume | encoded | a template the scenarios state (; undefined) | offensive |  |
| is governor of | assume | encoded | a template the scenarios state (; undefined) | is governor of |  |
| directed by Minister | assume | encoded | a template the scenarios state (; undefined) | directed by Minister |  |
| directed by States Assembly member | assume | encoded | a template the scenarios state (; undefined) | directed by States Assembly member |  |
| directed by equivalent in another jurisdiction | assume | encoded | a template the scenarios state (; undefined) | directed by equivalent in another jurisdiction |  |
| is registered | assume | encoded | a template the scenarios state (; undefined) | is registered |  |
| is deregistered | assume | encoded | a template the scenarios state (; undefined) | is deregistered |  |
| registration date | assume | encoded | a template the scenarios state (; undefined) | registration date |  |
| deregistration date | assume | encoded | a template the scenarios state (; undefined) | deregistration date |  |
| registration section | assume | encoded | a template the scenarios state (; undefined) | registration section |  |
| applied for registration | assume | encoded | a template the scenarios state (; undefined) | applied for registration |  |
| applied for deregistration | assume | encoded | a template the scenarios state (; undefined) | applied for deregistration |  |
| registration refused | assume | encoded | a template the scenarios state (; undefined) | registration refused |  |
| applied to change name | assume | encoded | a template the scenarios state (; undefined) | applied to change name |  |
| name change refused | assume | encoded | a template the scenarios state (; undefined) | name change refused |  |
| meets funding condition | assume | encoded | a template the scenarios state (; undefined) | meets funding condition |  |
| refrains from soliciting donations | assume | encoded | a template the scenarios state (; undefined) | refrains from soliciting donations |  |
| requested restricted section | assume | encoded | a template the scenarios state (; undefined) | requested restricted section |  |
| acts with due diligence | assume | encoded | a template the scenarios state (; undefined) | acts with due diligence |  |
| acts as prudent person | assume | encoded | a template the scenarios state (; undefined) | acts as prudent person |  |
| acts to best ability | assume | encoded | a template the scenarios state (; undefined) | acts to best ability |  |
| observes good faith | assume | encoded | a template the scenarios state (; undefined) | observes good faith |  |
| ensures consistency with purposes | assume | encoded | a template the scenarios state (; undefined) | ensures consistency with purposes |  |
| ensures compliance with law | assume | encoded | a template the scenarios state (; undefined) | ensures compliance with law |  |
| reportable matter exists | assume | encoded | a template the scenarios state (; undefined) | reportable matter exists |  |
| reported to charity | assume | encoded | a template the scenarios state (; undefined) | reported to charity |  |
| reported to Commissioner | assume | encoded | a template the scenarios state (; undefined) | reported to Commissioner |  |
| declared no reportable matters | assume | encoded | a template the scenarios state (; undefined) | declared no reportable matters |  |
| is fit and proper person | assume | encoded | a template the scenarios state (; undefined) | is fit and proper person |  |
| provides annual return | assume | encoded | a template the scenarios state (; undefined) | provides annual return |  |
| reports changes | assume | encoded | a template the scenarios state (; undefined) | reports changes |  |
| applies property per purposes | assume | encoded | a template the scenarios state (; undefined) | applies property per purposes |  |
| applies property per statement | assume | encoded | a template the scenarios state (; undefined) | applies property per statement |  |
| amended to non-charitable purpose | assume | encoded | a template the scenarios state (; undefined) | amended to non-charitable purpose |  |
| changed name without permission | assume | encoded | a template the scenarios state (; undefined) | changed name without permission |  |
| uses other than registered name | assume | encoded | a template the scenarios state (; undefined) | uses other than registered name |  |
| amended purposes without approval | assume | encoded | a template the scenarios state (; undefined) | amended purposes without approval |  |
| amended statement without approval | assume | encoded | a template the scenarios state (; undefined) | amended statement without approval |  |
| required steps notice served | assume | encoded | a template the scenarios state (; undefined) | required steps notice served |  |
| notice served on governor | assume | encoded | a template the scenarios state (; undefined) | notice served on governor |  |
| complied with notice | assume | encoded | a template the scenarios state (; undefined) | complied with notice |  |
| disqualification order exists | assume | encoded | a template the scenarios state (; undefined) | disqualification order exists |  |
| refers to as charity | assume | encoded | a template the scenarios state (; undefined) | refers to as charity |  |
| refers to as Jersey charity | assume | encoded | a template the scenarios state (; undefined) | refers to as Jersey charity |  |
| refers to as registered | assume | encoded | a template the scenarios state (; undefined) | refers to as registered |  |
| knows not registered | assume | encoded | a template the scenarios state (; undefined) | knows not registered |  |
| intends to mislead | assume | encoded | a template the scenarios state (; undefined) | intends to mislead |  |
| intends to gain advantage | assume | encoded | a template the scenarios state (; undefined) | intends to gain advantage |  |
| misconduct | assume | encoded | a template the scenarios state (; undefined) | misconduct |  |
| governor misconduct | assume | encoded | a template the scenarios state (; undefined) | governor misconduct |  |
| governor reportable matter | assume | encoded | a template the scenarios state (; undefined) | governor reportable matter |  |
| misled Commissioner | assume | encoded | a template the scenarios state (; undefined) | misled Commissioner |  |
| no longer exists | assume | encoded | a template the scenarios state (; undefined) | no longer exists |  |
| governor of registered charity | assume | encoded | a template the scenarios state (; undefined) | governor of registered charity |  |
| wholly managed in Jersey | assume | encoded | a template the scenarios state (; undefined) | wholly managed in Jersey |  |
| excepted foreign charity | assume | encoded | a template the scenarios state (; undefined) | excepted foreign charity |  |
| established under UK law | assume | encoded | a template the scenarios state (; undefined) | established under UK law |  |
| established under prescribed law | assume | encoded | a template the scenarios state (; undefined) | established under prescribed law |  |
| entitled to use charity term | assume | encoded | a template the scenarios state (; undefined) | entitled to use charity term |  |
| managed from establishment jurisdiction | assume | encoded | a template the scenarios state (; undefined) | managed from establishment jurisdiction |  |
| may appeal to tribunal | assume | encoded | a template the scenarios state (; undefined) | may appeal to tribunal |  |
| may appeal to court | assume | encoded | a template the scenarios state (; undefined) | may appeal to court |  |
| is required steps notice | assume | encoded | a template the scenarios state (; undefined) | is required steps notice |  |
| is deregistration decision | assume | encoded | a template the scenarios state (; undefined) | is deregistration decision |  |
| is registration refusal | assume | encoded | a template the scenarios state (; undefined) | is registration refusal |  |
| is name change refusal | assume | encoded | a template the scenarios state (; undefined) | is name change refusal |  |
| organized religious charity | assume | encoded | a template the scenarios state (; undefined) | organized religious charity |  |
| acquired before deregistration | assume | encoded | a template the scenarios state (; undefined) | acquired before deregistration |  |
| preserved charitable purposes | assume | encoded | a template the scenarios state (; undefined) | preserved charitable purposes |  |
| preserved public benefit statement | assume | encoded | a template the scenarios state (; undefined) | preserved public benefit statement |  |
| British Overseas Territories | record | encoded | a list of individuals, one fact per field | british_overseas_territories |  |
| isBOT | definition | encoded | pred | *a place* is BOT |  |
| qualifying territory | definition | encoded | pred | qualifying territory for *a place* |  |
| is ancillary | assume | encoded | a template the scenarios state (; undefined) | is ancillary |  |
| is analogous to charitable purpose | assume | encoded | a template the scenarios state (; undefined) | is analogous to charitable purpose |  |
| knownCharitablePurposes | definition | encoded | func | the known charitable purposes is *a list* |  |
| is charitable | wording | approximated | the template's words made from the name, its inputs appended | *a value* is charitable | to be reviewed: the name does not say where its inputs go |
| all purposes are qualifying | wording | approximated | the template's words made from the name, its inputs appended | all purposes are qualifying for *an entity* | to be reviewed: the name does not say where its inputs go |
| is charitable | definition | encoded | pred | *a value* is charitable |  |
| all purposes are qualifying | definition | encoded | pred | all purposes are qualifying for *an entity* |  |
| meets the charity test | definition | encoded | pred | *an entity* meets the charity test |  |
| eligible for registration as charity | definition | encoded | pred | eligible for registration as charity for *an entity* |  |
| is undesirable | definition | residue | no LE form found | r1 |  |
| eligible for restricted section | definition | encoded | pred | eligible for restricted section for *an entity* |  |
| complies with requirements | definition | encoded | pred | complies with requirements for *an entity* |  |
| fulfills governor duties | definition | encoded | pred | fulfills governor duties for *a person* with *an entity* |  |
| may refer to as Jersey charity | definition | encoded | pred | *an entity* may refer to as jersey charity for *an user* |  |
| may refer to as charity | definition | encoded | pred | *an entity* may refer to as charity for *an user* |  |
| excepted foreign charity | definition | residue | no LE form found | r2 |  |
| may issue required steps notice | definition | encoded | pred | *an entity* may issue required steps notice |  |
| may deregister | definition | encoded | pred | *an entity* may deregister |  |
| must apply property for preserved purposes | definition | encoded | pred | *an entity* must apply *a property* for preserved purposes |  |
| may appeal to tribunal | definition | residue | no LE form found | r3 |  |
| in public register | assume | encoded | a template the scenarios state (; undefined) | in public register |  |
| general section | assume | encoded | a template the scenarios state (; undefined) | general section |  |
| restricted section public elements | assume | encoded | a template the scenarios state (; undefined) | restricted section public elements |  |
| historic section | assume | encoded | a template the scenarios state (; undefined) | historic section |  |
| disclosure to authorized person | assume | encoded | a template the scenarios state (; undefined) | disclosure to authorized person |  |
| for investigation of offense | assume | encoded | a template the scenarios state (; undefined) | for investigation of offense |  |
| for legal proceedings | assume | encoded | a template the scenarios state (; undefined) | for legal proceedings |  |
| may disclose | definition | encoded | pred | *a person* may disclose for *an info* |  |
| may require governor removal | definition | encoded | pred | *an entity* may require governor removal for *a notice* |  |

## Residue

- **is undesirable** (definition) — no LE form found; in the program: r1. 
- **excepted foreign charity** (definition) — no LE form found; in the program: r2. 
- **may appeal to tribunal** (definition) — no LE form found; in the program: r3. 

