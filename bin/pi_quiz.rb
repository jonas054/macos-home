PI_DECIMALS = '3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679'.freeze

def quiz_on_pi
  puts 'Welcome to the Pi Decimal Quiz!'
  puts 'Enter the first 100 decimals of Pi:'

  input = ''
  correct = true
  index = 0

  while index < PI_DECIMALS.length
    char = $stdin.getc

    if char == PI_DECIMALS[index]
      print char
      index += 1
    end
  end

  if correct
    puts 'Congratulations! You got it right!'
  else
    puts 'Incorrect! Better luck next time!'
  end
end

quiz_on_pi
