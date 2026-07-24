extends Node

const MOTIVATION_MESSAGES = [
	"Top delikte bekliyor, atış yapmaya hazır mısın?",
	"Zihnini boşaltmanın en iyi yolu: Slide Golf!",
	"Yarım kalan seviyeni tamamlamak için seni bekliyoruz.",
	"Elmaslar seni bekliyor, gel ve topla!",
	"Bugün biraz zihin jimnastiğine ne dersin?",
	"Sadece 5 dakika oynamak bile stresi azaltır!",
	"Rekorunu kırmaya hazır mısın?",
	"Yeni bölümler keşfedilmeyi bekliyor.",
	"Golf sahası seni özledi!",
	"Hadi gel, birkaç bulmaca çözelim."
]

func _ready():
	schedule_daily_notification()

func schedule_daily_notification():
	if Engine.has_singleton("GodotLocalNotification"):
		var ln = Engine.get_singleton("GodotLocalNotification")
		var msg = MOTIVATION_MESSAGES[randi() % MOTIVATION_MESSAGES.size()]
		
		# Cancel previous notifications (if plugin supports it)
		if ln.has_method("cancelAllNotifications"):
			ln.cancelAllNotifications()
		elif ln.has_method("cancel_all_notifications"):
			ln.cancel_all_notifications()
			
		# Schedule for 24 hours from now (86400 seconds)
		if ln.has_method("showLocalNotification"):
			ln.showLocalNotification(msg, "Slide Golf", 86400, 1)
		elif ln.has_method("show_local_notification"):
			ln.show_local_notification(msg, "Slide Golf", 86400, 1)
		elif ln.has_method("show"):
			ln.show(msg, "Slide Golf", 86400, 1)
			
		print("NotificationManager: Scheduled daily local notification.")
	else:
		print("NotificationManager: GodotLocalNotification singleton not found. Please install the Android plugin.")
