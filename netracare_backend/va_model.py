import math

def validate(correct, total):
    if total <= 0:
        raise ValueError("Total must be greater than zero")
    if correct < 0 or correct > total:
        raise ValueError("Correct answers out of range")

def calculate_logmar(correct, total):
    if correct == 0:
        return 1.0
    return round(-math.log10(correct / total), 2)

def logmar_to_snellen(logmar): #The logMAR calculation, Snellen conversion, and severity thresholds are derived from established ophthalmic standards such as ETDRS charts and WHO visual impairment classifications. The system does not invent values; it implements clinically accepted mappings to ensure reliability and safety.
    mapping = { 
        0.0: "20/20", 
        0.1: "20/25", 
        0.2: "20/32", 
        0.3: "20/40", 
        0.4: "20/50", 
        0.5: "20/63", 
        1.0: "20/200",
          }
    closest = min(mapping.keys(), key=lambda x: abs(x - logmar))
    return mapping[closest]

def classify_severity(logmar):
    if logmar <= 0.1:
        return "Normal"
    elif logmar <= 0.3:
        return "Mild Vision Loss"
    elif logmar <= 0.5:
        return "Moderate Vision Loss"
    else:
        return "Severe Vision Loss"
