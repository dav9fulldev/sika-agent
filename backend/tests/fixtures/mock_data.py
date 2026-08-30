# Mock data for tests

MOCK_WALLETS = [
    {
        "provider": "wave",
        "name": "Wave Wallet",
        "balance": 50000.0,
        "currency": "XOF",
        "account_number": "+2250701020304"
    },
    {
        "provider": "orange_money",
        "name": "Orange Money",
        "balance": 25000.0,
        "currency": "XOF",
        "account_number": "+2250705060708"
    },
    {
        "provider": "mtn_money",
        "name": "MTN Mobile Money",
        "balance": 15000.0,
        "currency": "XOF",
        "account_number": "+2250505060708"
    }
]

MOCK_TRANSACTIONS = [
    {
        "id": "tx_101",
        "provider": "wave",
        "type": "transfer",
        "amount": 5000.0,
        "currency": "XOF",
        "recipient": "Kouamé",
        "sender": null,
        "timestamp": "2026-08-15T14:30:00Z",
        "status": "completed",
        "category": "Transfert",
        "description": "Transfert sortant Wave vers Kouamé"
    },
    {
        "id": "tx_102",
        "provider": "wave",
        "type": "received",
        "amount": 10000.0,
        "currency": "XOF",
        "recipient": null,
        "sender": "Mamadou",
        "timestamp": "2026-08-15T10:15:00Z",
        "status": "completed",
        "category": "Revenu",
        "description": "Réception d'argent Wave de Mamadou"
    },
    {
        "id": "tx_103",
        "provider": "orange_money",
        "type": "payment",
        "amount": 2500.0,
        "currency": "XOF",
        "recipient": "Boulangerie Abidjan",
        "sender": null,
        "timestamp": "2026-08-14T18:45:00Z",
        "status": "completed",
        "category": "Alimentation",
        "description": "Achat boulangerie"
    },
    {
        "id": "tx_104",
        "provider": "mtn_money",
        "type": "withdrawal",
        "amount": 20000.0,
        "currency": "XOF",
        "recipient": "Point Cash Yopougon",
        "sender": null,
        "timestamp": "2026-08-12T09:00:00Z",
        "status": "completed",
        "category": "Retrait",
        "description": "Retrait d'espèces"
    }
]

MOCK_CONTACTS = [
    {"name": "Kouamé", "phone": "+2250701112233", "favorite_provider": "wave"},
    {"name": "Mamadou", "phone": "+2250702223344", "favorite_provider": "wave"},
    {"name": "Maman", "phone": "+2250703334455", "favorite_provider": "orange_money"},
    {"name": "Awa", "phone": "+2250504445566", "favorite_provider": "mtn_money"}
]
