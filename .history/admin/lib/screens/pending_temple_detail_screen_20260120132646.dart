if (project['status'] == 'rejected') {
   return RejectedCard();
} else if (project['isSanctioned'] == true) {
   return SanctionedCard();
}