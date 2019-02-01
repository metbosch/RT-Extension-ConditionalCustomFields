use strict;
use warnings;

use RT::Extension::ConditionalCustomFields::Test tests => 14;

use WWW::Mechanize::PhantomJS;

my $cf_condition = RT::CustomField->new(RT->SystemUser);
$cf_condition->Create(Name => 'Condition', Type => 'Select', MaxValues => 1, Queue => 'General');
$cf_condition->AddValue(Name => 'Passed', SortOder => 0);
$cf_condition->AddValue(Name => 'Failed', SortOrder => 1);
$cf_condition->AddValue(Name => 'Schrödingerized', SortOrder => 2);
my $cf_values = $cf_condition->Values->ItemsArrayRef;

my $cf_conditioned_by = RT::CustomField->new(RT->SystemUser);
$cf_conditioned_by->Create(Name => 'ConditionedBy', Type => 'Select', MaxValues => 1, Queue => 'General');
$cf_conditioned_by->AddValue(Name => 'Conditioned Passed', SortOder => 0);
$cf_conditioned_by->AddValue(Name => 'Conditioned Failed', SortOrder => 1);
$cf_conditioned_by->AddValue(Name => 'Conditioned Schrödingerized', SortOrder => 2);
my $cf_conditioned_by_values = $cf_conditioned_by->Values->ItemsArrayRef;

my $cf_conditioned_by_child = RT::CustomField->new(RT->SystemUser);
$cf_conditioned_by_child->Create(Name => 'Child', Type => 'Freeform', MaxValues => 1, Queue => 'General');

$cf_conditioned_by->SetConditionedBy($cf_condition->id, 'is', [$cf_values->[0]->Name, $cf_values->[2]->Name]);
$cf_conditioned_by_child->SetConditionedBy($cf_conditioned_by->id, 'is', [$cf_conditioned_by_values->[0]->Name, $cf_conditioned_by_values->[2]->Name]);

RT->Config->Set('CustomFieldGroupings',
    'RT::Ticket' => [
        'Group one' => ['Condition'],
        'Group two' => ['ConditionedBy'],
    ],
);

my $ticket = RT::Ticket->new(RT->SystemUser);
$ticket->Create(Queue => 'General', Subject => 'Test Ticket ConditionalCF');
$ticket->AddCustomFieldValue(Field => $cf_condition->id , Value => $cf_values->[0]->Name);
$ticket->AddCustomFieldValue(Field => $cf_conditioned_by->id , Value => $cf_conditioned_by_values->[0]->Name);
$ticket->AddCustomFieldValue(Field => $cf_conditioned_by_child->id , Value => 'See me?');

my ($base, $m) = RT::Extension::ConditionalCustomFields::Test->started_ok;
my $mjs = WWW::Mechanize::PhantomJS->new();
$mjs->get($m->rt_base_url . '?user=root;pass=password');

$mjs->get($m->rt_base_url . 'Ticket/Display.html?id=' . $ticket->id);
my $ticket_cf_conditioned_by = $mjs->selector('#CF-'. $cf_conditioned_by->id . '-ShowRow', single => 1);
ok($ticket_cf_conditioned_by->is_displayed, 'Show ConditionalCF when both conditions are passed');
my $ticket_cf_conditioned_by_child = $mjs->selector('#CF-'. $cf_conditioned_by_child->id . '-ShowRow', single => 1);
ok($ticket_cf_conditioned_by_child->is_displayed, 'Show Child when both conditions are passed');

$ticket->AddCustomFieldValue(Field => $cf_conditioned_by->id , Value => $cf_conditioned_by_values->[1]->Name);

$mjs->get($m->rt_base_url . 'Ticket/Display.html?id=' . $ticket->id);
$ticket_cf_conditioned_by = $mjs->selector('#CF-'. $cf_conditioned_by->id . '-ShowRow', single => 1);
ok($ticket_cf_conditioned_by->is_displayed, 'Show ConditionalCF when parent condition is passed and child condition is failed');
$ticket_cf_conditioned_by_child = $mjs->selector('#CF-'. $cf_conditioned_by_child->id . '-ShowRow', single => 1);
ok($ticket_cf_conditioned_by_child->is_hidden, 'Hide Child when parent condition is passed and child condition is failed');

$ticket->AddCustomFieldValue(Field => $cf_condition->id , Value => $cf_values->[1]->Name);

$mjs->get($m->rt_base_url . 'Ticket/Display.html?id=' . $ticket->id);
$ticket_cf_conditioned_by = $mjs->selector('#CF-'. $cf_conditioned_by->id . '-ShowRow', single => 1);
ok($ticket_cf_conditioned_by->is_hidden, 'Hide ConditionalCF when both conditions are failed');
$ticket_cf_conditioned_by_child = $mjs->selector('#CF-'. $cf_conditioned_by_child->id . '-ShowRow', single => 1);
ok($ticket_cf_conditioned_by_child->is_hidden, 'Hide Child when both conditions are failed');

$ticket->AddCustomFieldValue(Field => $cf_conditioned_by->id , Value => $cf_conditioned_by_values->[0]->Name);

$mjs->get($m->rt_base_url . 'Ticket/Display.html?id=' . $ticket->id);
$ticket_cf_conditioned_by = $mjs->selector('#CF-'. $cf_conditioned_by->id . '-ShowRow', single => 1);
ok($ticket_cf_conditioned_by->is_hidden, 'Hide ConditionalCF when parent condition is failed and child condition is passed');
$ticket_cf_conditioned_by_child = $mjs->selector('#CF-'. $cf_conditioned_by_child->id . '-ShowRow', single => 1);
ok($ticket_cf_conditioned_by_child->is_hidden, 'Hide Child when parent condition is failed and child condition is passed');