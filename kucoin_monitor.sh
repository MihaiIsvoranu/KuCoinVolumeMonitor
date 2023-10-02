#!/bin/bash

LANG=C LC_ALL=C

echo "0" > total_number_of_coins
while :; do
  curl -s "https://api.binance.com/api/v3/ticker/price" | jq -r '.[].symbol' | sed -e '/USDT/!d' -e 's/USDT//g' > binance_coins
  curl -s "https://api.kucoin.com/api/v1/market/allTickers" | jq -r ".data.ticker[].symbol" | sed -e '/USDT/!d' -e 's/-USDT//g'  > kucoin_coins
  comm -13 <(sort binance_coins) <(sort kucoin_coins) | sed '/USD/d' > all_coins
  
  totalNumberOfCoins=$(wc -l < all_coins)

  if [[ $totalNumberOfCoins != $(cat total_number_of_coins) ]]; then
    rm -r coins/
    mkdir coins
    echo "$totalNumberOfCoins" > total_number_of_coins
    while read -r line; do mkdir "coins/$line-USDT"; done < all_coins
  fi

  curl -s "https://api.kucoin.com/api/v1/market/allTickers" > tickers
  for i in coins/*; do
    coinPair="${i#*/}"
    jq -r --arg coinPair "$coinPair" '.data.ticker[] | select(.symbol==$coinPair) | .last' tickers > "$i/last_price_1"
    jq -r --arg coinPair "$coinPair" '.data.ticker[] | select(.symbol==$coinPair) | .volValue' tickers > "$i/last_volume_1"
  done

  sleep 8m

  curl -s "https://api.kucoin.com/api/v1/market/allTickers" > tickers
  for i in coins/*; do
    coinPair="${i#*/}"
    jq -r --arg coinPair "$coinPair" '.data.ticker[] | select(.symbol==$coinPair) | .last' tickers > "$i/last_price_2"
    jq -r --arg coinPair "$coinPair" '.data.ticker[] | select(.symbol==$coinPair) | .volValue' tickers > "$i/last_volume_2"
  done

  for i in coins/*; do
    read -r lastprice2 < "$i/last_price_2" ; read -r lastprice1 < "$i/last_price_1"
    read -r lastvolume2 < "$i/last_volume_2" ; read -r lastvolume1 < "$i/last_volume_1"
    read -r bidrate < "$i/bidrate" ; read -r askrate < "$i/askrate"

    coinPair="${i#*/}"
    volumeChange=$(awk -v t1="$lastvolume1" -v t2="$lastvolume2" 'BEGIN{print (t2-t1)/t1 * 100}')
    priceChange=$(awk -v t1="$lastprice1" -v t2="$lastprice2" 'BEGIN{print (t2-t1)/t1 * 100}')

	if (( $(echo "$volumeChange > 5" | bc -l) )); then
      echo -e "$coinPair\nPrice change: $priceChange%\nVolume change: $volumeChange%\n\n" >> msg
	fi
  done
done &
