###Datos del cuestionario 
db_0or1row get_session {SELECT * FROM as_sessions s WHERE s.session_id = :session_id}
ns_log notice "--- entra a esta parte 3 "
set assessment_item_id [content::revision::item_id -revision_id $assessment_id]
ns_log notice "--- entra a esta parte 4 $assessment_id :: $assessment_item_id"
######

### Datos del la unidad 
#set page_id [db_string get_item_id {select item_id from content_activities where activity_id =:assessment_item_id }]
set page_id [db_string get_item_id {select ca.item_id from content_activities as ca left join cr_items as cr on ca.item_id = cr.item_id where cr.item_id is not null and activity_id =:assessment_item_id order by item_id desc limit 1}]

ns_log notice "--- entra a esta parte 5 page $page_id"
set category_id [category::get_mapped_categories  $page_id]
set unit_id [category::get_parent -category_id $category_id]
set tree_id [category::get_tree $unit_id]
#####

### datos sesion 
#set percent_score [db_string score "SELECT percent_score FROM as_sessions s WHERE s.session_id = :session_id" -default 0]
set secction_points [db_string get_points {SELECT points from as_session_sections asec, as_section_data asd where asec.session_id = asd.session_id and asec.section_id = asd.section_id and asec.session_id = :session_id} -default 0]
ns_log notice "--- entra a esta parte 6 $secction_points :: session $percent_score"
#######

### Validacion de aprobado #####
if {$activity_mode eq "single" && ($percent_score >= $pass_percent_score || $secction_points >=  $pass_percent_score)} {
    set goto_next 1
    ns_log notice "--- entra a esta parte 6 a $activity_mode : $goto_next"
    
} elseif {$activity_mode eq "multiple"} {
    set activity_objects [category::get_objects -category_id $category_id]
    set objects_all [join $activity_objects ","]
    set approve_activitys [db_list_of_lists get "select distinct cr.item_id from as_sessions sec, cr_revisions cr,content_activities ca where revision_id = sec.assessment_id and completed_datetime is not null and cr.item_id = ca.activity_id and ca.item_id in ($objects_all) and percent_score > :pass_percent_score and subject_id =  :subject_id"]
    
    if {[expr [llength $approve_activitys] / [llength $activity_objects]] >= 0.6} {
	set goto_next 1
    }
    ns_log notice "--- entra a esta parte 6 b $activity_mode : [expr [llength $approve_activitys] / [llength $activity_objects]]"
}

if {$goto_next} {
    ns_log notice "--- entra a esta parte Ganar $secction_points :: session $percent_score"
    set tree [category_tree::get_tree_levels -only_level $tree_levels $tree_id]
    set next_unit_index  [expr [lsearch -exact -regexp $tree $unit_id] + 1]
    ns_log notice "--- entra a esta parte Ganar 1 $tree , $next_unit_index "
    
    if {$next_unit_index < [llength $tree]} {
	ns_log notice "--- entra a esta parte Ganar 2"
	set unit_id [lindex $tree $next_unit_index 0]
	ns_log notice "--- entra a esta parte Ganar $unit_id"
	set nex_unit_tree [category_tree::get_tree -subtree_id  $unit_id $tree_id]
	set next_activity [lindex $nex_unit_tree [lsearch -exact -regexp $nex_unit_tree $activity_name] 0]
	permission::grant -party_id $party_id -object_id $unit_id -privilege read
	permission::grant -party_id $party_id -object_id $next_activity -privilege read
	set  message_text "Completa la siguiente actividad para avanzar con el curso"
	set redirect_url [learning_content::category::first_page -category_id  $unit_id -package_id $xo_package_id -user_id $party_id -permissions]
    } else {
	ns_log notice "--- entra a esta parte Ganar todo"
	set  message_text "Has completado el 100 del primer curso de Introducción a Matemáticas"
	set redirect_url [dotlrn_community::get_community_url [dotlrn_community::get_community_id]]
    }
    ns_log notice "--- entra a esta parte permisos ganar"
} else {
    ns_log notice "--- entra a esta parte perder"
    permission::grant -party_id $party_id -object_id $unit_id -privilege read 
    ns_log notice "--- from assessment $assessment_item_id | page $page_id | category $category_id | unit $unit_id | tree $tree_id"
    foreach category [category_tree::get_tree -subtree_id $unit_id  $tree_id ] {
	set category_id [lindex $category 0]
	permission::grant -party_id $party_id -object_id $category_id -privilege read
	ns_log notice "assessment da permisos $category_id"
	set redirect_url [learning_content::category::first_page -category_id  $unit_id -package_id $xo_package_id -user_id $party_id -permissions]
	set  message_text "Favor repasar el contenido de la Unidad para poder continuar"
    }
}
#set message_text "ya paso"
set message ""
ns_log notice "---- final"
ns_log notice "---- parete redirigir 1 $xo_package_id , $redirect_url"

if {$redirect_url eq "" || $redirect_url eq "#"} {
    set redirect_url [apm_package_url_from_id $xo_package_id]
    ns_log notice "---- pretende redirigir 1 $xo_package_id , $redirect_url"
}

#set redirect_url [learning_content::category::first_page -category_id  $unit_id -package_id $xo_package_id -user_id $party_id -permissions]
ns_log notice "---- parete redirigir 2 $redirect_url"

ad_progress_bar_end -message_after_redirect "$message_text" -url $redirect_url
set new_messages [ad_get_client_property -default {} -cache_only t "acs-kernel" "general_messages"]
lappend new_messages $message
ad_set_client_property "acs-kernel" "general_messages" $new_messages
ad_script_abort

