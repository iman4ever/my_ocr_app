import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../database/receipt_model.dart'; // Import for ReceiptItem

class ReceiptParser {

  // ... (existing getSortedText) ...

  static List<ReceiptItem> extractItems(String text) {
    List<ReceiptItem> items = [];
    final lines = text.split('\n');
    final RegExp priceRegex = RegExp(r'([0-9]+[.,][0-9]{2})');
    final RegExp weightPattern = RegExp(r'\d+.*(kg|x|mad|lb|g )', caseSensitive: false);
    final RegExp dateRegex = RegExp(r'(\d{2}[/.-]\d{2}[/.-]\d{4})|(\d{4}[/.-]\d{2}[/.-]\d{2})');
    
    // Categories to strip from the start of item names
    final List<String> categoryPrefixes = [
      'FRUITS & LEGUMES', 'FRUITS ET LEGUMES', 'CREMERIE LS', 'CREMERIE', 'BISCUITERIE & CONFIS',
      'EPICERIE', 'BISCUITERIE', 'POISSONNERIE', 'BOUCHERIE', 'BOULANGERIE', 'BOUTIQUE', 'BOUTIQUE LS',    
    ];
    
    print("DEBUG: Extracting Items from ${lines.length} lines...");
    
    // 1. DETERMINE HEADER END (Structural Fix)
    // We look for the last occurrence of specific header markers to skip address lines.
    // LIMIT SEARCH to top 20 lines to avoid finding footer dates or "Nombre Articles" at the bottom.
    int startIndex = 0;
    int limit = lines.length < 20 ? lines.length : 20;
    
    for (int i = 0; i < limit; i++) {
        String lower = lines[i].toLowerCase();
        
        // IMPORTANT: Don't skip if the line also contains a price!
        // On Aswak receipts, "OPERATION : VENTE" appears on the same line as the first item
        // Example: "OPERATION : VENTE 4.95" with "NECTAR..." 
        bool hasPrice = priceRegex.hasMatch(lines[i]);
        
        // If line contains Date, "Operation", "Vente", "Ticket", "Pos", "Caissier" -> It's likely header info.
        // We set start index to the *next* line.
        // BUT: Only if it doesn't also have a price (which would make it an item line)
        if (!hasPrice && (dateRegex.hasMatch(lines[i]) || 
            lower.contains('operation') || 
            lower.contains('vente') ||
            lower.contains('ticket') || 
            (lower.contains('article') && !lower.contains('nombre')) || // Avoid "Nombre articles" footer
            lower.contains('tel:') || 
            lower.contains('fax:') ||
            lower.contains('patente') ||
            lower.contains('ice:') ||
            lower.contains('cap sur'))) {
            
            startIndex = i + 1;
        }
    }
    
    // Safety: If header skip is too aggressive (ignoring > 50% of receipt), reset it.
    if (startIndex > lines.length * 0.5) {
        print("DEBUG: Header skip index $startIndex is too large (>50%). Resetting to 0.");
        startIndex = 0;
    }
    
    print("DEBUG: Structural Header Skip -> Starting item scan at line $startIndex");

    String? pendingName;

    for (int i = startIndex; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;
      
      String lower = line.toLowerCase();
      String lowerClean = lower.replaceAll(' ', '').replaceAll('.', ''); 

      // CRITICAL STOP: Footer keywords (Added 'paienent' typo)
      if (lower.contains('ventilation') || 
          lower.contains('paiement') || 
          lower.contains('paienent') || 
          lower.contains('nombre article') || 
          lower.contains('net à payer') ||
          lower.contains('net a payer')) {
         print("DEBUG: Hit footer section '$line'. Stopping item parsing.");
         break;
      }
      
      // Blocklist - Generic Noise
      if (lower.contains('total') || lower.contains('sum') || lower.contains('merci') || 
          lower.contains('change') || lower.contains('espece') || lower.contains('rendu') ||
          lower.contains('tva') || lower.contains('tax') || 
          lower.contains('timbre') || lower.contains('tinbre') || lower.contains('droit') ||
          lower.contains('net à payer') || 
          lower.contains('ttc') || lowerClean.contains('ttc') || lower.contains('dh') ||
          lower.contains('tot.ht') || lower.contains('codetot') ||
          lower.contains('gratuit')) {
        
        if (lower.contains('total') || lowerClean.contains('ttc')) pendingName = null;
        print("  -> Rejected: Keyword blocklist");
        continue;
      }
      
      // DETECT MULTI-ITEM LINES: Disabled for now - OCR quality is too unreliable
      // When OCR merges lines, it often scrambles the order of items and prices
      // Making it impossible to correctly split them
      // Users can manually edit items in the confirmation dialog instead
      
      /*
      final priceMatches = priceRegex.allMatches(line);
      
      // Filter out unit prices (those with 'x' before or after them)
      List<RegExpMatch> itemPrices = [];
      for (var match in priceMatches) {
          int start = match.start;
          int end = match.end;
          
          String before = start > 0 ? line.substring(max(0, start - 3), start).toLowerCase() : '';
          String after = end < line.length ? line.substring(end, min(line.length, end + 3)).toLowerCase() : '';
          
          if (before.contains('x') || after.trim().startsWith('x')) {
              continue;
          }
          
          itemPrices.add(match);
      }
      
      if (itemPrices.length >= 2) {
          // Splitting logic here...
      }
      */


      final matches = priceRegex.allMatches(line);
      if (matches.isNotEmpty) {
         // IMPROVED: Check if there are multiple prices on the line
         // If so, prefer the LAST one (usually the total, not unit price)
         // UNLESS the line is very long (100+ chars) which suggests OCR merged multiple items
         // In that case, use the FIRST price to at least get one item correct
         
         RegExpMatch selectedMatch;
         if (matches.length >= 2 && line.length > 100) {
             // Long line with multiple prices - likely merged items
             // Filter out unit prices and use the first real item price
             print("  -> WARNING: Long line (${line.length} chars) with ${matches.length} prices - likely merged items");
             
             RegExpMatch? firstNonUnitPrice;
             for (var match in matches) {
                 int start = match.start;
                 int end = match.end;
                 String before = start > 0 ? line.substring(max(0, start - 3), start).toLowerCase() : '';
                 String after = end < line.length ? line.substring(end, min(line.length, end + 3)).toLowerCase() : '';
                 
                 if (!before.contains('x') && !after.trim().startsWith('x')) {
                     firstNonUnitPrice = match;
                     print("  -> Using first non-unit price: ${match.group(0)}");
                     break;
                 }
             }
             selectedMatch = firstNonUnitPrice ?? matches.last;
         } else {
             selectedMatch = matches.last;
         }
         
         String priceStr = selectedMatch.group(1)!.replaceAll(',', '.');
         double? price = double.tryParse(priceStr);
         
         String currentName = line.substring(0, selectedMatch.start).trim();
         
         // STRIP BARCODES: Remove patterns like (2>611124210736 or (5)21001260000778
         currentName = currentName.replaceAll(RegExp(r'\([0-9>)]+\s*\d+'), '').trim();
         
         // CLEANUP: Strip category prefixes
         String originalName = currentName;
         for (var prefix in categoryPrefixes) {
           if (currentName.toUpperCase().startsWith(prefix)) {
             currentName = currentName.substring(prefix.length).trim();
             print("  -> Stripped category '$prefix', remaining: '$currentName'");
             break; // Only strip once
           }
         }
         
         // Don't strip too aggressively, or we lose "AUBERGINE" if it has numbers
         String cleanName = currentName.replaceAll(RegExp(r'[^a-zA-Z0-9\s%.]+$'), ''); 
         
         // Count letters in the cleaned name
         int letterCount = cleanName.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
         
         // BLOCK "Category + Price" lines and partial category names
         // After stripping category, we need at least 4 letters for a valid item name
         // This prevents "& CONF IS 3.00" (from "BISCUITERIE & CONF IS 3.00") from being added
         if (letterCount < 4) {
            print("  -> Rejected: Category-only or too short line '$line' (letters: $letterCount)");
            continue;
         }
         
         // Also reject if the name starts with common category connectors
         String lowerName = cleanName.toLowerCase();
         if (lowerName.startsWith('&') || lowerName.startsWith('et ') || lowerName.startsWith('ls ')) {
            print("  -> Rejected: Category connector line '$line'");
            continue;
         }
         
         if (price != null) {
             // UNIT PRICE CHECK
             // If the match is immediately followed by "MAD", "kg", "x", or "/", it's likely a unit price.
             // We want the TOTAL price (usually at the end).
             int matchEnd = selectedMatch.end;
             String textAfterPrice = line.substring(matchEnd).trim().toUpperCase();
             bool isUnitPrice = textAfterPrice.startsWith('MAD') || 
                                textAfterPrice.startsWith('DH') || 
                                textAfterPrice.startsWith('/') || 
                                textAfterPrice.startsWith('KG') ||
                                textAfterPrice.startsWith('X');
                                
             // ALWAYS check for a better price at the very end of the line
             // This handles cases like "4.95 MAD/kg 0.85" where we want 0.85
             final endNumberRegex = RegExp(r'(\d+[.,]\d{1,2})$');  // Match 1-2 decimals
             final endMatch = endNumberRegex.firstMatch(line.trim());
             
             if (endMatch != null && endMatch.start >= matchEnd) {
                // There's a price at the end that's AFTER our current match
                try {
                  double endPrice = double.parse(endMatch.group(1)!.replaceAll(',', '.'));
                  if (endPrice != price) {
                     print("  -> Found better price at end: $endPrice (was $price)");
                     price = endPrice;
                     isUnitPrice = false; // The end price is the real total
                  }
                } catch (e) {}
             } else if (isUnitPrice) {
                 print("  -> Warning: '$price' looks like a Unit Price ($textAfterPrice), but no better price found.");
                 // We'll use this price but flag it
             }

             // DECISION: Is the current line a "Weight/Detail" line?
             // It is ONLY a weight line if it matches the pattern AND has few letters.
             // WE RELAX letter count if 'matchesWeightPattern' is true (handles 'kg x MAD/kg')
             // IMPORTANT: Check pattern on FULL LINE, not just cleanName!
             bool matchesWeightPattern = weightPattern.hasMatch(line); // Check FULL line for pattern, not just name
             
             // NEW: Weight lines typically START with a number (0.129 kg) or have very few letters
             // This prevents "AUBERGINE KG" from being treated as a weight line
             bool startsWithNumber = RegExp(r'^\d').hasMatch(cleanName.trim());
             
             // Handle "PRIX PROMOTION" logic
             bool hasPromo = lower.contains('prix promotion');
             bool isPromoLine = false;
             
             if (hasPromo) {
                 // Check if it has a real name besides "PRIX PROMOTION"
                 String nameWithoutPromo = lowerClean.replaceAll('prix', '').replaceAll('promotion', '');
                 int remainingLetters = nameWithoutPromo.replaceAll(RegExp(r'[^a-z]'), '').length;
                 if (remainingLetters < 3) {
                     isPromoLine = true; // True promo line (just price)
                 }
             }

             // If matches weight pattern, allow MORE letters (up to 24) to account for units/verbose descriptions.
             // "0.129 kg x 5.95 MAD/kg" -> letters: kg, x, m, a, d, k, g = 7 letters (plus spaces).
             // Relaxed to 24 purely based on user feedback to ensure capture.
             // BUT: Only if it starts with a number OR has very few letters (< 8)
             // This prevents "AUBERGINE KG" (10 letters, doesn't start with number) from being a weight line
             bool isWeightLine = (matchesWeightPattern && (startsWithNumber || letterCount < 8)) || 
                                 cleanName.length < 3 || 
                                 isPromoLine;
             
             if (isWeightLine) {
                 if (pendingName != null) {
                     // MERGE: Valid merge
                     // CONCATENATE NAMES as requested: "AUBERGINE" + "0.129 kg..."
                     String mergedName = "$pendingName $cleanName";
                     
                     if (!isUnitPrice) {
                        print("  ->MERGED ITEM: $mergedName -> $price");
                        items.add(ReceiptItem(name: mergedName, price: price!));
                     } else {
                        // If only unit price found, keep pending name? 
                        // Or add with 0.0?
                        // Let's assume we missed the total. Add with 0.0 or flag? 
                        // User prefers NO price than wrong price.
                        // Actually, if we merge, we consume PendingName.
                        print("  ->MERGED ITEM (Unit Price ignored): $mergedName -> $price");
                        items.add(ReceiptItem(name: mergedName, price: price!)); // Fallback to Unit Price if forced
                     }
                     pendingName = null;
                 } else if (items.isNotEmpty && !isPromoLine) {
                     // ORPHAN WEIGHT LINE found, but we have a previous item.
                     // IMPORTANT: Only update if it's a true weight line (has kg/MAD pattern)
                     // NOT if it's just a "PRIX PROMOTION" line - those belong to pending items only!
                     print("  -> UPDATING PRICE: Previous '${items.last.name}' (${items.last.price}) -> $price");
                     if (!isUnitPrice) {
                        ReceiptItem last = items.removeLast();
                        items.add(ReceiptItem(name: last.name, price: price!));
                     } else {
                        print("  -> Ignored Price Update (Unit Price detected)");
                     }
                 } else {
                     print("  -> Rejected: Orphan weight/detail line ($line)");
                 }
             } else {
                 // Normal Item line (Mixed or Pure)
                 // SPECIAL CASE: If the line has BOTH a good name (8+ letters) AND weight pattern,
                 // it's likely "NAVET BLANC 0.095 kg x 8.95 MAD/kg"
                 // In this case, store as pendingName and wait for the PRIX PROMOTION line
                 if (matchesWeightPattern && letterCount >= 8 && isUnitPrice) {
                     print("  -> PENDING (has weight details inline): $cleanName");
                     pendingName = cleanName;
                 } else if (hasPromo && letterCount >= 8) {
                     // SPECIAL CASE 2: If line contains "PRIX PROMOTION" with a good name,
                     // it means there's more detail coming (like a weight line)
                     // Example: "COURGETTE BLANCHE PRIX PROMOTION 0.85"
                     
                     // BUT: If there's a pendingName, the price actually belongs to the PENDING item!
                     // This is because OCR merges lines: "NAVET..." then "COURGETTE PRIX PROMOTION 0.85"
                     // where 0.85 is actually NAVET's price, not COURGETTE's!
                     String nameOnly = cleanName.replaceAll(RegExp(r'PRIX PROMOTION', caseSensitive: false), '').trim();
                     
                     if (pendingName != null) {
                         print("  -> MERGED ITEM (OCR line merge fix): $pendingName -> $price");
                         items.add(ReceiptItem(name: pendingName, price: price!));
                         print("  -> PENDING (has PRIX PROMOTION, waiting for details): $nameOnly");
                         pendingName = nameOnly;
                     } else {
                         print("  -> PENDING (has PRIX PROMOTION, waiting for details): $nameOnly");
                         pendingName = nameOnly;
                     }
                 } else if (letterCount > 2) {
                     // Before adding new item, flush any pending name
                     if (pendingName != null) {
                         print("  -> FLUSHING PENDING: $pendingName (no price found, using 0.0)");
                         items.add(ReceiptItem(name: pendingName, price: 0.0));
                         pendingName = null;
                     }
                     
                     // Clean "PRIX PROMOTION" from item name
                     String finalName = cleanName.replaceAll(RegExp(r'PRIX PROMOTION', caseSensitive: false), '').trim();
                     print("  -> ACCEPTED ITEM: $finalName - $price");
                     items.add(ReceiptItem(name: finalName, price: price!));
                     pendingName = null;
                 } else if (pendingName != null) {
                     // Fallback
                     print("  ->MERGED ITEM (Fallback): $pendingName -> $price");
                     items.add(ReceiptItem(name: pendingName, price: price!));
                     pendingName = null;
                 } else {
                    print("  -> Rejected: Too short/numeric name ($cleanName)");
                 }
             }
         } else {
            print("  -> Rejected: Price parsing failed");
         }
      } else {
         // NO PRICE: Potential Name
         int letterCount = line.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
         if (letterCount > 2) {
             // CLEANUP: Strip category prefixes
             String tempName = line.trim();
             for (var prefix in categoryPrefixes) {
               if (tempName.toUpperCase().startsWith(prefix)) {
                 tempName = tempName.substring(prefix.length).trim();
               }
             }
             if (tempName.length > 2) {
               print("  -> Storing as pending name: '$tempName'");
               pendingName = tempName; 
             }
         } else {
            print("  -> Rejected: Not a name candidate");
         }
      }
    }
    return items;
  }



  // Organize text by vertical position AND merge lines on the same row
  static String getSortedText(RecognizedText recognizedText) {
    List<TextLine> allLines = [];
    for (var block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }
    
    // 1. Sort primarily by Y, then by X
    allLines.sort((a, b) {
      int yDiff = a.boundingBox.top.toInt() - b.boundingBox.top.toInt();
      // Tolerance of 10-20px for "same line"
      if (yDiff.abs() < 20) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return yDiff;
    });

    if (allLines.isEmpty) return "";

    // 2. Merge lines that are visually on the same row
    List<String> mergedLines = [];
    List<TextLine> currentRow = [allLines.first];
    
    for (int i = 1; i < allLines.length; i++) {
        TextLine current = allLines[i];
        TextLine previous = currentRow.last; 
        
        // If vertical difference is small, they are on the same line
        if ((current.boundingBox.top - previous.boundingBox.top).abs() < 24) {
            currentRow.add(current);
        } else {
            // Commit current row
            // Sort by X just in case
            currentRow.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
            mergedLines.add(currentRow.map((e) => e.text).join(" ")); 
            currentRow = [current];
        }
    }
    // Commit last row
    currentRow.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    mergedLines.add(currentRow.map((e) => e.text).join(" "));

    return mergedLines.join('\n');
  }

  
  static double extractAmount(String text) {
    if (text.isEmpty) return 0.0;
    final lowerText = text.toLowerCase();
    final lines = lowerText.split('\n');
    
    print("DEBUG: --- START EXTRACT AMOUNT ---");
    
    // 1. Precise Keyword Search for "Total"
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      // Check for specific "Total" keywords
      if (line.contains('total') || line.contains('ttc') || line.contains('net à payer') || line.contains('montant')) {
         print("DEBUG: Found TOTAL keyword in line: '$line'");
         
         // Ignore if it's a subtotal or tax details
         if (line.contains('tva')) {
            print("  -> Ignored (contains TVA)");
            continue;
         }
         
         // HARD REJECT 0.06 REMOVED - It was skipping valid lines like "Timedre 0.06 Total 22.24"
         // Checks for value 0.06 are now done AFTER extraction.
         
         // If line contains "Rendu" or "Espece", we need to be careful.
         // We want the price closest to the word "Total".
         double? amount = _findPriceAssociatedWithTotal(line);
         if (amount != null) {
             print("  -> Found amount on same line: $amount");
             // Double check it's not small
             if (amount > 0.1 && amount != 0.06) return amount;
         }
         
         // Check next 5 lines (Aswak Salam puts total far below label)
         for (int j = 1; j <= 5 && i + j < lines.length; j++) {
            String nextLine = lines[i+j];
            String nextLower = nextLine.toLowerCase();
            print("  -> Checking next line [+$j]: '$nextLine'");
            
            if (nextLower.contains('total') || nextLower.contains('rendu') || nextLower.contains('espece')) {
                 print("  -> Stopped deep search (found another keyword)");
                 break; 
            }
            
            // SKIP lines with TIMBRE/DROIT variants (Fix for 0.06 bug)
            if (nextLower.contains('timbre') || nextLower.contains('tinbre') || 
                nextLower.contains('tembre') || nextLower.contains('droit') || 
                nextLower.contains('tax') || nextLower.contains('tva')) {
                print("  -> Skipped line (Timbre/Tax keyword)");
                continue;
            }
            
            double? nextAmount = _findLastPriceInString(nextLine);
            if (nextAmount != null) {
                if (nextAmount == 0.06) {
                    print("  -> Found 0.06, ignoring it.");
                    continue;
                }
                print("  -> Found deep amount: $nextAmount");
                return nextAmount;
            }
         }
      }
    }
    
    print("DEBUG: Fallback strategy...");
    // 2. Fallback: Find largest number that looks like a valid price
    try {
      final allPrices = _findAllPricesWithContext(lines);
      if (allPrices.isNotEmpty) {
        double maxP = allPrices.reduce((curr, next) => curr > next ? curr : next);
        print("DEBUG: Fallback max price: $maxP");
        if (maxP == 0.06) return 0.0;
        return maxP;
      }
    } catch (e) {
      // ignore
    }

    return 0.0;
  }
  
  // Helper to find the price logically associated with "Total" on the same line
  static double? _findPriceAssociatedWithTotal(String line) {
     final lower = line.toLowerCase();
     final keywordRegex = RegExp(r'(total|ttc|net à payer|montant)');
     final keywordMatch = keywordRegex.firstMatch(lower);
     if (keywordMatch == null) return null;
     
     // Find all prices
     final priceRegex = RegExp(r'([0-9]+[.,][0-9]{2})');
     final priceMatches = priceRegex.allMatches(line);
     
     if (priceMatches.isEmpty) return null;
     
     // If only one price, return it (Validate not 0.06)
     if (priceMatches.length == 1) {
         String match = priceMatches.first.group(1)!;
         double val = double.parse(match.replaceAll(',', '.'));
         if (val == 0.06) return null;
         return val;
     }
     
     // If multiple prices, find the one closest to the 'Total' keyword (Start of price - End of keyword)
     // We assume Total <Price>. 
     double? bestPrice;
     int minDistance = 99999;
     
     for (var pm in priceMatches) {
        String valStr = pm.group(1)!;
        double? val = double.tryParse(valStr.replaceAll(',', '.'));
        if (val == null) continue;
        
        // IGNORE 0.06 (Timbre)
        if (val == 0.06) {
             print("    -> _findPriceAssociatedWithTotal skipped 0.06");
             continue;
        }

        // Calculate distance. 
        // If price is AFTER keyword: distance = pm.start - match.end
        // If price is BEFORE keyword: distance = match.start - pm.end
        
        int dist;
        if (pm.start >= keywordMatch.end) {
            dist = pm.start - keywordMatch.end;
        } else {
             // Price before total? e.g. "10.00 Total"
            dist = keywordMatch.start - pm.end;
        }
        
        if (dist.abs() < minDistance) {
           minDistance = dist.abs();
           bestPrice = val;
        }
     }
     
     return bestPrice;
  }
  
  static double? _findLastPriceInString(String text) {
     // Matches: 12.34, 12,34. Excludes integers.
     final RegExp priceRegex = RegExp(r'[0-9]+[.,][0-9]{2}');
     final matches = priceRegex.allMatches(text);
     if (matches.isNotEmpty) {
        String match = matches.last.group(0)!;
        match = match.replaceAll(',', '.');
        return double.tryParse(match);
     }
     return null;
  }
  
  static List<double> _findAllPricesWithContext(List<String> lines) {
     final RegExp priceRegex = RegExp(r'[0-9]+[.,][0-9]{2}');
     List<double> prices = [];
     
     for (var line in lines) {
       final lower = line.toLowerCase();
       // EXCLUSION LIST: Payment methods, Change, Tax details (TVA sometimes has amounts)
       if (lower.contains('espece') || lower.contains('espèces') || 
           lower.contains('rendu') || lower.contains('cash') || 
           lower.contains('change') || lower.contains('tva') ||
           lower.contains('remise') || lower.contains('bancaire')) {
         continue;
       }
       
       final matches = priceRegex.allMatches(line);
       for (var m in matches) {
          String val = m.group(0)!.replaceAll(',', '.');
          double? p = double.tryParse(val);
          if (p != null) {
             if (p > 2000 && p < 2100) continue; // Probable year
             prices.add(p);
          }
       }
     }
     return prices;
  }

  static DateTime extractDate(String text) {
    // Look for strict patterns like DD/MM/YYYY or YYYY-MM-DD
    final RegExp dateRegex = RegExp(r'(\d{2}[/.-]\d{2}[/.-]\d{4})|(\d{4}[/.-]\d{2}[/.-]\d{2})');
    final matches = dateRegex.allMatches(text);
    
    for (var match in matches) {
      try {
        String dateStr = match.group(0)!;
        dateStr = dateStr.replaceAll('.', '/').replaceAll('-', '/').replaceAll(' ', '/');
        
        DateTime? dt;
        if (dateStr.contains('/')) {
           final parts = dateStr.split('/');
           // Case YYYY/MM/DD
           if (parts[0].length == 4) {
             dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
           } 
           // Case DD/MM/YYYY
           else if (parts[2].length == 4) {
             dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
           }
        }
        
        // Validate year to be recent (e.g., 2020-2030) to avoid catching random numbers
        if (dt != null && dt.year >= 2020 && dt.year <= 2030) {
          return dt;
        }
      } catch (e) {
        continue;
      }
    }
    
    return DateTime.now();
  }
  
  static String extractMerchant(String text) {
    if (text.isEmpty) return "Unknown";
    final lines = text.split('\n');
    
    // Known brands to prioritize immediately
    final List<String> knownBrands = [
      'BIM', 'MARJANE', 'ASWAK ASSALAM', 'CARREFOUR', 'ACIMA', 'GLOVO', 'JUMIA', 'ATACADAO', 'IKEA', 'DECATHLON', 'LC WAIKIKI', 'MCDONALDS', 'KFC', 'BURGER KING'
    ];
    
    // Common Typo Map
    final Map<String, String> typoMap = {
      'BIH': 'BIM',
      '8IM': 'BIM',
      'B1M': 'BIM',
      'ASWAK': 'ASWAK ASSALAM',
      'MARJANE MARKET': 'MARJANE'
    };
    
    String? bestCandidate;
    int maxScore = -1;

    print("DEBUG: Extracting Merchant from top lines...");
    
    // Check top 12 lines (increased search space)
    for (int i=0; i < lines.length && i < 12; i++) {
       String line = lines[i].trim();
       if (line.isEmpty) continue;
       
       String upperLine = line.toUpperCase();
       
       // 0. Immediate Brand Match (Fuzzy & Typo)
       // Check Typo Map first
       for (var typo in typoMap.keys) {
         if (upperLine.contains(typo)) {
            print("  -> FOUND TYPO MATCH: $typo -> ${typoMap[typo]}");
            return typoMap[typo]!;
         }
       }
       
       for (var brand in knownBrands) {
         if (upperLine.contains(brand)) {
           print("  -> FOUND KNOWN BRAND: $brand");
           return brand; 
         }
       }
       
       // Scoring System
       int score = 0;
       
       // 1. Min Length
       if (line.length < 3) continue;
       
       // 2. Reject if mostly numbers/symbols
       int digitCount = line.replaceAll(RegExp(r'[^0-9]'), '').length;
       int letterCount = line.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
       int symbolCount = line.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length;
       
       if (letterCount < 3) continue; // Must have letters
       if (digitCount > letterCount) continue; // More numbers than letters = Trash/ID
       if (symbolCount > letterCount) continue; // More symbols than letters = Garbage/Separator
       
       // 3. Blocklist
       if (line.toLowerCase().contains('ticket') || 
          line.toLowerCase().contains('bienvenue') ||
          line.toLowerCase().contains('recu') ||
          line.toLowerCase().contains('bonjour') ||
          line.toLowerCase().contains('tel') ||
          line.toLowerCase().contains('fax') ||
          line.toLowerCase().contains('patente') ||
          line.toLowerCase().contains('ice') ||
          line.toLowerCase().contains('cnss') ||
          line.toLowerCase().contains('idf')) continue;

       // 4. Calculate Score
       score += 10; // Base score for passing filters
       
       // Bonus: All Uppercase (Shop names are usually uppercase)
       if (line == line.toUpperCase()) score += 5;
       
       // Bonus: No numbers at all (Clean name)
       if (digitCount == 0) score += 5;
       
       // Bonus: Length boost (avoid short abbreviations)
       if (line.length > 5) score += 2;
       
       // Penalty: Symbols (-, *, .) often indicate headers or noise
       score -= (symbolCount * 2);
       
       print("  -> Candidate: '$line' (Score: $score)");
       
       if (score > maxScore) {
         maxScore = score;
         bestCandidate = line;
       }
    }
    
    if (bestCandidate != null) {
      print("  -> SELECTED BEST: $bestCandidate");
      // Clean up result (uppercase)
      return bestCandidate.toUpperCase(); 
    }
    
    return "Unknown Merchant";
  }
}